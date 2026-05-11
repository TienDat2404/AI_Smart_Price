using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    /// <summary>
    /// Quản lý số dư ví người dùng.
    /// Số dư = tổng thu nhập - tổng chi tiêu từ Transactions collection.
    /// Không lưu balance riêng — tính toán real-time để đảm bảo nhất quán.
    /// </summary>
    [ApiController]
    [Route("api/wallet")]
    public class WalletController : ControllerBase
    {
        private readonly IMongoCollection<Transaction> _transactions;

        public WalletController(IMongoDatabase db)
        {
            _transactions = db.GetCollection<Transaction>("Transactions");
        }

        // ── GET /api/wallet/balance?userId=user_01 ────────────────────────────

        /// <summary>
        /// Lấy số dư thực tế mới nhất của người dùng.
        /// Tính từ toàn bộ lịch sử giao dịch: balance = income - expense.
        /// </summary>
        [HttpGet("balance")]
        [ProducesResponseType(typeof(WalletBalanceDto), 200)]
        public async Task<IActionResult> GetBalance([FromQuery] string userId = "user_01")
        {
            var filter = Builders<Transaction>.Filter.Eq(t => t.UserId, userId);
            var all    = await _transactions.Find(filter).ToListAsync();

            var totalIncome  = all.Where(t => !t.IsExpense).Sum(t => (double)t.Amount);
            var totalExpense = all.Where(t => t.IsExpense).Sum(t => (double)t.Amount);
            var balance      = totalIncome - totalExpense;

            // Tháng hiện tại
            var now        = DateTime.UtcNow;
            var monthStart = new DateTime(now.Year, now.Month, 1);
            var thisMonth  = all.Where(t => t.Date >= monthStart).ToList();
            var monthIncome  = thisMonth.Where(t => !t.IsExpense).Sum(t => (double)t.Amount);
            var monthExpense = thisMonth.Where(t => t.IsExpense).Sum(t => (double)t.Amount);

            return Ok(new WalletBalanceDto(
                UserId:       userId,
                Balance:      balance,
                TotalIncome:  totalIncome,
                TotalExpense: totalExpense,
                MonthIncome:  monthIncome,
                MonthExpense: monthExpense,
                MonthBalance: monthIncome - monthExpense,
                UpdatedAt:    DateTime.UtcNow
            ));
        }

        // ── POST /api/wallet/deposit ──────────────────────────────────────────

        /// <summary>
        /// Nạp tiền vào ví — tạo giao dịch Thu nhập.
        /// Dùng khi user muốn cập nhật số dư ban đầu.
        /// </summary>
        [HttpPost("deposit")]
        [ProducesResponseType(typeof(Transaction), 201)]
        public async Task<IActionResult> Deposit([FromBody] DepositRequest request)
        {
            if (request.Amount <= 0)
                return BadRequest(new { message = "Số tiền phải lớn hơn 0." });

            var tx = new Transaction
            {
                Id       = null,
                UserId   = request.UserId ?? "user_01",
                ItemName = request.Note ?? "Nạp tiền vào ví",
                Amount   = (decimal)request.Amount,
                Category = "Thu nhập",
                Note     = request.Note ?? "Nạp tiền",
                Date     = DateTime.UtcNow,
                IsExpense = false,
            };

            await _transactions.InsertOneAsync(tx);
            return CreatedAtAction(nameof(GetBalance), new { userId = tx.UserId }, tx);
        }
    }

    // ── DTOs ──────────────────────────────────────────────────────────────────

    public record WalletBalanceDto(
        string   UserId,
        double   Balance,
        double   TotalIncome,
        double   TotalExpense,
        double   MonthIncome,
        double   MonthExpense,
        double   MonthBalance,
        DateTime UpdatedAt
    );

    public record DepositRequest(
        string? UserId,
        double  Amount,
        string? Note
    );
}
