using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TransactionsController : ControllerBase
    {
        private readonly IMongoCollection<Transaction>  _collection;
        private readonly IMongoCollection<BankAccount> _bankAccounts;

        public TransactionsController(IMongoDatabase db)
        {
            _collection   = db.GetCollection<Transaction>("Transactions");
            _bankAccounts = db.GetCollection<BankAccount>("BankAccounts");
        }

        // GET api/transactions
        [HttpGet]
        public async Task<ActionResult<List<Transaction>>> GetAll(
            [FromQuery] string? userId,
            [FromQuery] string? category,
            [FromQuery] DateTime? from,
            [FromQuery] DateTime? to)
        {
            var builder = Builders<Transaction>.Filter;
            var filter  = builder.Empty;

            if (!string.IsNullOrEmpty(userId))
                filter &= builder.Eq(t => t.UserId, userId);

            if (!string.IsNullOrEmpty(category))
                filter &= builder.Eq(t => t.Category, category);

            if (from.HasValue)
                filter &= builder.Gte(t => t.Date, from.Value);

            if (to.HasValue)
                filter &= builder.Lte(t => t.Date, to.Value);

            var results = await _collection
                .Find(filter)
                .SortByDescending(t => t.Date)
                .ToListAsync();

            return Ok(results);
        }

        // GET api/transactions/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<Transaction>> GetById(string id)
        {
            var transaction = await _collection
                .Find(t => t.Id == id)
                .FirstOrDefaultAsync();

            if (transaction is null)
                return NotFound(new { message = $"Không tìm thấy giao dịch với id: {id}" });

            return Ok(transaction);
        }

        // POST api/transactions
        [HttpPost]
        public async Task<ActionResult<object>> Create([FromBody] Transaction transaction)
        {
            transaction.Id   = null;
            transaction.Date = transaction.Date == default ? DateTime.UtcNow : transaction.Date;

            await _collection.InsertOneAsync(transaction);

            // ── Cập nhật BankAccounts.Balance (Hướng B) ──────────────────────
            // Mọi giao dịch (thủ công / OCR / Voice / SePay) đều ảnh hưởng số dư ví.
            // Tìm tài khoản ngân hàng đã liên kết của user → cộng/trừ balance.
            var bankAccount = await _bankAccounts
                .Find(b => b.UserId == transaction.UserId && b.Status == "active")
                .FirstOrDefaultAsync();

            if (bankAccount != null)
            {
                // Bỏ qua giao dịch "Điều chỉnh" (từ EditWalletScreen) và giao dịch từ SePay
                // vì SePay đã tự cập nhật balance trong webhook riêng
                var isAdjustment = transaction.Category is "Điều chỉnh" or "Dieu chinh";
                var isSePayTx    = transaction.Note?.StartsWith("[SePay]") == true;

                if (!isAdjustment && !isSePayTx)
                {
                    var delta = transaction.IsExpense
                        ? -(decimal)transaction.Amount
                        :  (decimal)transaction.Amount;

                    await _bankAccounts.UpdateOneAsync(
                        b => b.Id == bankAccount.Id,
                        Builders<BankAccount>.Update
                            .Inc(b => b.Balance, delta)
                            .Set(b => b.LastSyncAt, DateTime.UtcNow)
                    );
                }
            }

            // Tính lại số dư sau khi lưu — trả về cùng response để client cập nhật UI ngay
            var filter       = Builders<Transaction>.Filter.Eq(t => t.UserId, transaction.UserId);
            var all          = await _collection.Find(filter).ToListAsync();
            var totalIncome  = all.Where(t => !t.IsExpense).Sum(t => (double)t.Amount);
            var totalExpense = all.Where(t => t.IsExpense).Sum(t => (double)t.Amount);
            var newBalance   = totalIncome - totalExpense;

            // Lấy bank balance mới nhất để trả về client
            var updatedBank = await _bankAccounts
                .Find(b => b.UserId == transaction.UserId && b.Status == "active")
                .FirstOrDefaultAsync();
            var bankBalance = updatedBank != null ? (double)updatedBank.Balance : newBalance;

            return CreatedAtAction(nameof(GetById), new { id = transaction.Id }, new
            {
                transaction,
                newBalance   = bankBalance,   // ← trả bank balance thực
                totalIncome,
                totalExpense,
            });
        }

        // PUT api/transactions/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(string id, [FromBody] Transaction updated)
        {
            var result = await _collection.ReplaceOneAsync(t => t.Id == id, updated);

            if (result.MatchedCount == 0)
                return NotFound(new { message = $"Không tìm thấy giao dịch với id: {id}" });

            return NoContent();
        }

        // DELETE api/transactions/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            var result = await _collection.DeleteOneAsync(t => t.Id == id);

            if (result.DeletedCount == 0)
                return NotFound(new { message = $"Không tìm thấy giao dịch với id: {id}" });

            return NoContent();
        }

        // GET api/transactions/stats?userId=user_01
        [HttpGet("stats")]
        public async Task<ActionResult<object>> GetStats([FromQuery] string? userId)
        {
            var filter = string.IsNullOrEmpty(userId)
                ? Builders<Transaction>.Filter.Empty
                : Builders<Transaction>.Filter.Eq(t => t.UserId, userId);

            var all = await _collection.Find(filter).ToListAsync();

            var totalExpense = all.Where(t => t.IsExpense).Sum(t => t.Amount);
            var totalIncome  = all.Where(t => !t.IsExpense).Sum(t => t.Amount);

            // ── Số dư tháng hiện tại ──────────────────────────────────────────
            var now       = DateTime.UtcNow;
            var monthStart = new DateTime(now.Year, now.Month, 1);
            var thisMonth  = all.Where(t => t.Date >= monthStart).ToList();
            var monthExpense = thisMonth.Where(t => t.IsExpense).Sum(t => t.Amount);
            var monthIncome  = thisMonth.Where(t => !t.IsExpense).Sum(t => t.Amount);

            // balance = tổng thu nhập - tổng chi tiêu (toàn thời gian)
            // Nếu âm nghĩa là chi tiêu > thu nhập trong dữ liệu hiện có
            // → trả thêm monthBalance để UI có thể chọn hiển thị
            return Ok(new
            {
                totalTransactions = all.Count,
                totalExpense      = (double)totalExpense,
                totalIncome       = (double)totalIncome,
                balance           = (double)(totalIncome - totalExpense),
                monthExpense      = (double)monthExpense,
                monthIncome       = (double)monthIncome,
                monthBalance      = (double)(monthIncome - monthExpense),
            });
        }

        // GET api/transactions/recent?userId=user_01&limit=5
        [HttpGet("recent")]
        public async Task<ActionResult<List<Transaction>>> GetRecent(
            [FromQuery] string? userId,
            [FromQuery] int limit = 5)
        {
            var filter = string.IsNullOrEmpty(userId)
                ? Builders<Transaction>.Filter.Empty
                : Builders<Transaction>.Filter.Eq(t => t.UserId, userId);

            var results = await _collection
                .Find(filter)
                .SortByDescending(t => t.Date)
                .Limit(limit)
                .ToListAsync();

            return Ok(results);
        }
    }
}
