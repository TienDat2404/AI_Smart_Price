using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    /// <summary>
    /// Quản lý liên kết tài khoản ngân hàng qua SePay.
    ///
    /// GET    /api/bank-accounts?userId=...       — danh sách tài khoản liên kết
    /// POST   /api/bank-accounts/link             — liên kết tài khoản mới
    /// DELETE /api/bank-accounts/{id}             — hủy liên kết
    /// POST   /api/bank-accounts/webhook/sepay    — nhận webhook từ SePay
    /// </summary>
    [ApiController]
    [Route("api/bank-accounts")]
    public class BankAccountController : ControllerBase
    {
        private readonly IMongoCollection<BankAccount> _bankAccounts;
        private readonly IMongoCollection<Transaction> _transactions;
        private readonly IMongoCollection<SystemError> _errors;
        private readonly ILogger<BankAccountController> _logger;

        public BankAccountController(
            IMongoDatabase db,
            ILogger<BankAccountController> logger)
        {
            _bankAccounts = db.GetCollection<BankAccount>("BankAccounts");
            _transactions = db.GetCollection<Transaction>("Transactions");
            _errors       = db.GetCollection<SystemError>("SystemErrors");
            _logger       = logger;
        }

        // ── GET /api/bank-accounts?userId=... ────────────────────────────────

        [HttpGet]
        public async Task<IActionResult> GetByUser([FromQuery] string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return BadRequest(new { message = "userId is required." });

            var accounts = await _bankAccounts
                .Find(x => x.UserId == userId)
                .SortByDescending(x => x.CreatedAt)
                .ToListAsync();

            var dtos = accounts.Select(ToDto).ToList();
            return Ok(dtos);
        }

        // ── POST /api/bank-accounts/link ─────────────────────────────────────

        [HttpPost("link")]
        public async Task<IActionResult> Link([FromBody] LinkBankRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.SePayToken))
                return BadRequest(new { message = "SePayToken không được để trống." });

            if (string.IsNullOrWhiteSpace(req.AccountNumber))
                return BadRequest(new { message = "Số tài khoản không được để trống." });

            // Kiểm tra trùng: cùng UserId + cùng số tài khoản
            var exists = await _bankAccounts.Find(x =>
                x.UserId == req.UserId &&
                x.AccountNumber == req.AccountNumber).AnyAsync();

            if (exists)
                return Conflict(new { message = "Tài khoản này đã được liên kết." });

            var account = new BankAccount
            {
                UserId        = req.UserId,
                BankName      = req.BankName,
                AccountNumber = req.AccountNumber,
                AccountHolder = req.AccountHolder,
                SePayToken    = req.SePayToken,
                Balance       = 0,
                Status        = "active",
                CreatedAt     = DateTime.UtcNow,
            };

            await _bankAccounts.InsertOneAsync(account);
            _logger.LogInformation("Bank linked: {Bank} {Account} for user {UserId}",
                req.BankName, req.AccountNumber, req.UserId);

            return Ok(ToDto(account));
        }

        // ── DELETE /api/bank-accounts/{id} ───────────────────────────────────

        [HttpDelete("{id}")]
        public async Task<IActionResult> Unlink(string id)
        {
            var result = await _bankAccounts.DeleteOneAsync(x => x.Id == id);
            if (result.DeletedCount == 0)
                return NotFound(new { message = "Không tìm thấy tài khoản." });

            return Ok(new { message = "Đã hủy liên kết tài khoản." });
        }

        // ── POST /api/bank-accounts/webhook/sepay ────────────────────────────
        //
        // SePay gọi endpoint này mỗi khi có biến động số dư.
        // Payload mẫu từ SePay:
        // {
        //   "id": 12345,
        //   "gateway": "MBBank",
        //   "transactionDate": "2024-01-15 14:30:00",
        //   "accountNumber": "0123456789",
        //   "code": "SMARTPRICE_user_01",
        //   "content": "SMARTPRICE001 nop tien thue",
        //   "transferType": "in",          // "in" = tiền vào, "out" = tiền ra
        //   "transferAmount": 500000,
        //   "accumulated": 15000000,       // số dư sau giao dịch
        //   "referenceCode": "FT24015123456"
        // }

        [HttpPost("webhook/sepay")]
        public async Task<IActionResult> SePayWebhook([FromBody] SePayWebhookPayload payload)
        {
            _logger.LogInformation("SePay webhook: {Gateway} {AccountNumber} {Type} {Amount}",
                payload.Gateway, payload.AccountNumber, payload.TransferType, payload.TransferAmount);

            try
            {
                // 1. Tìm tài khoản ngân hàng khớp với số tài khoản
                var account = await _bankAccounts
                    .Find(x => x.AccountNumber == payload.AccountNumber && x.Status == "active")
                    .FirstOrDefaultAsync();

                if (account == null)
                {
                    _logger.LogWarning("SePay webhook: No linked account for {AccountNumber}", payload.AccountNumber);
                    // Trả 200 để SePay không retry
                    return Ok(new { message = "Account not linked." });
                }

                // 2. Cập nhật số dư:
                //    - Nếu accumulated > 0 (ngân hàng trả số dư thực) → dùng luôn
                //    - Nếu accumulated = 0 (MB Bank không trả) → cộng/trừ dần từ balance hiện tại
                var isExpenseWebhook = payload.TransferType?.ToLower() == "out";
                decimal newBalance;

                if (payload.Accumulated > 0)
                {
                    // Ngân hàng trả số dư thực (VPBank, Techcombank...)
                    newBalance = (decimal)payload.Accumulated;
                }
                else
                {
                    // MB Bank không trả accumulated → tính incremental
                    var delta = isExpenseWebhook
                        ? -(decimal)payload.TransferAmount
                        :  (decimal)payload.TransferAmount;
                    newBalance = account.Balance + delta;
                }

                await _bankAccounts.UpdateOneAsync(
                    x => x.Id == account.Id,
                    Builders<BankAccount>.Update
                        .Set(x => x.Balance,    newBalance)
                        .Set(x => x.LastSyncAt, DateTime.UtcNow)
                    );

                // 3. Tạo giao dịch tự động trong Transactions
                var isExpense = payload.TransferType?.ToLower() == "out";
                var content   = payload.Content ?? payload.Description ?? "";

                // Phân loại thông minh từ nội dung chuyển khoản
                var (category, itemName) = ClassifyTransaction(content, isExpense);

                var transaction = new Transaction
                {
                    UserId    = account.UserId,
                    ItemName  = itemName,
                    Amount    = (decimal)payload.TransferAmount,
                    Date      = ParseDate(payload.TransactionDate),
                    Category  = category,
                    IsExpense = isExpense,
                    Note      = $"[SePay] {content}".Trim(),
                };

                await _transactions.InsertOneAsync(transaction);

                _logger.LogInformation(
                    "Auto transaction created: {ItemName} {Amount} for user {UserId}",
                    itemName, payload.TransferAmount, account.UserId);

                return Ok(new { success = true, transactionId = transaction.Id });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SePay webhook processing failed");

                await _errors.InsertOneAsync(new SystemError
                {
                    Source     = "SePay",
                    Message    = $"Webhook xử lý thất bại: {ex.Message}",
                    Level      = "error",
                    IsResolved = false,
                    OccurredAt = DateTime.UtcNow,
                });

                // Trả 200 để SePay không retry vô hạn
                return Ok(new { success = false, error = ex.Message });
            }
        }

        // ── PATCH /api/bank-accounts/{id}/set-initial-balance ───────────────
        /// <summary>
        /// Người dùng nhập số dư thực tế hiện tại của tài khoản ngân hàng.
        /// Chỉ cần làm một lần sau khi liên kết — sau đó webhook tự cộng/trừ.
        /// </summary>
        [HttpPatch("{id}/set-initial-balance")]
        public async Task<IActionResult> SetInitialBalance(string id, [FromBody] SetBalanceRequest req)
        {
            if (req.Balance < 0)
                return BadRequest(new { message = "Số dư không hợp lệ." });

            var result = await _bankAccounts.UpdateOneAsync(
                x => x.Id == id,
                Builders<BankAccount>.Update
                    .Set(x => x.Balance,    (decimal)req.Balance)
                    .Set(x => x.LastSyncAt, DateTime.UtcNow)
            );

            if (result.MatchedCount == 0)
                return NotFound(new { message = "Không tìm thấy tài khoản." });

            _logger.LogInformation("Initial balance set: {Id} = {Balance}", id, req.Balance);
            return Ok(new { message = "Đã cập nhật số dư ban đầu.", balance = req.Balance });
        }

        // ── GET /api/bank-accounts/supported-banks ───────────────────────────

        [HttpGet("supported-banks")]
        public IActionResult GetSupportedBanks()
        {
            var banks = new[]
            {
                new { code = "MBBank",      name = "MB Bank",      logo = "mb" },
                new { code = "Techcombank", name = "Techcombank",  logo = "tcb" },
                new { code = "VPBank",      name = "VPBank",       logo = "vpb" },
                new { code = "BIDV",        name = "BIDV",         logo = "bidv" },
                new { code = "VietinBank",  name = "VietinBank",   logo = "vti" },
                new { code = "Vietcombank", name = "Vietcombank",  logo = "vcb" },
                new { code = "TPBank",      name = "TPBank",       logo = "tpb" },
                new { code = "ACB",         name = "ACB",          logo = "acb" },
                new { code = "OCB",         name = "OCB",          logo = "ocb" },
                new { code = "MSB",         name = "MSB",          logo = "msb" },
            };
            return Ok(banks);
        }

        // ── Smart classifier ──────────────────────────────────────────────────

        /// <summary>
        /// Phân loại giao dịch từ nội dung chuyển khoản ngân hàng.
        /// Trả về (category, itemName) phù hợp.
        /// </summary>
        private static (string category, string itemName) ClassifyTransaction(
            string content, bool isExpense)
        {
            if (string.IsNullOrWhiteSpace(content))
                return isExpense ? ("Chuyển khoản", "Chuyển tiền") : ("Thu nhập", "Nhận tiền");

            var lower = content.ToLowerInvariant();

            // ── Thu nhập ──────────────────────────────────────────────────────
            if (!isExpense)
            {
                if (Contains(lower, "luong", "lương", "salary"))
                    return ("Thu nhập", "Nhận lương");
                if (Contains(lower, "thuong", "thưởng", "bonus"))
                    return ("Thu nhập", "Nhận thưởng");
                if (Contains(lower, "hoan tien", "hoàn tiền", "refund", "hoan tra", "hoàn trả"))
                    return ("Thu nhập", "Hoàn tiền");
                if (Contains(lower, "freelance", "cong tac phi", "công tác phí"))
                    return ("Thu nhập", "Thu nhập Freelance");
                return ("Thu nhập", "Nhận chuyển khoản");
            }

            // ── Chi tiêu — phân loại theo keyword ─────────────────────────────

            // Ăn uống
            if (Contains(lower, "pho", "phở", "com", "cơm", "bun", "bún", "banh mi",
                         "bánh mì", "cafe", "cà phê", "coffee", "tra sua", "trà sữa",
                         "an uong", "ăn uống", "nha hang", "nhà hàng", "quan an",
                         "quán ăn", "circle k", "7-eleven", "ministop", "grab food",
                         "grabfood", "shopeefood", "baemin", "gojek food",
                         "highlands", "the coffee", "lotteria", "mcdo", "kfc",
                         "pizza", "burger", "milk tea", "tra sua"))
                return ("Ăn uống", ExtractMerchant(content, "Ăn uống"));

            // Di chuyển
            if (Contains(lower, "grab", "be app", "gojek", "taxi", "xang", "xăng",
                         "petrol", "fuel", "gas station", "xe om", "xe buyt", "xe buýt",
                         "bus", "ve tau", "vé tàu", "ve may bay", "vé máy bay",
                         "vietjet", "bamboo", "vietnam airlines", "tien xe", "tiền xe",
                         "parking", "bai xe", "bãi xe", "go viet", "goviet"))
                return ("Di chuyển", ExtractMerchant(content, "Di chuyển"));

            // Mua sắm
            if (Contains(lower, "shopee", "lazada", "tiki", "sendo", "winmart",
                         "vinmart", "big c", "lotte mart", "coopmart", "aeon",
                         "ikea", "uniqlo", "muoi gio", "10 gio", "mua hang",
                         "mua sam", "mua sắm", "order", "cod", "thu ho"))
                return ("Mua sắm", ExtractMerchant(content, "Mua sắm"));

            // Hóa đơn / Tiện ích
            if (Contains(lower, "dien luc", "điện lực", "evn", "tien dien",
                         "tiền điện", "tien nuoc", "tiền nước", "internet",
                         "viettel", "mobifone", "vinaphone", "vnpt", "fpt",
                         "nap tien dien thoai", "nạp tiền", "topup",
                         "bao hiem", "bảo hiểm", "insurance",
                         "hop dong", "hợp đồng", "rent", "thue nha", "thuê nhà"))
                return ("Hóa đơn", ExtractMerchant(content, "Hóa đơn"));

            // Sức khỏe
            if (Contains(lower, "benh vien", "bệnh viện", "phong kham", "phòng khám",
                         "thuoc", "thuốc", "nha thuoc", "nhà thuốc", "pharmacy",
                         "bac si", "bác sĩ", "clinic", "hospital", "y te", "y tế",
                         "xet nghiem", "xét nghiệm", "gym", "the duc", "thể dục"))
                return ("Sức khỏe", ExtractMerchant(content, "Sức khỏe"));

            // Giải trí
            if (Contains(lower, "cinema", "cgv", "lotte cinema", "bhd", "galaxy",
                         "phim", "game", "steam", "netflix", "spotify",
                         "youtube", "karaoke", "billiard", "bida", "bar",
                         "giai tri", "giải trí", "du lich", "du lịch", "tour"))
                return ("Giải trí", ExtractMerchant(content, "Giải trí"));

            // Giáo dục
            if (Contains(lower, "hoc phi", "học phí", "truong", "trường", "school",
                         "university", "hoc vien", "học viện", "khoa hoc",
                         "khóa học", "course", "ielts", "toeic", "sach", "sách"))
                return ("Giáo dục", ExtractMerchant(content, "Giáo dục"));

            // Mặc định: chuyển khoản thông thường
            return ("Chuyển khoản", ExtractMerchant(content, "Chuyển tiền"));
        }

        /// <summary>Trích xuất tên merchant từ nội dung để dùng làm ItemName.</summary>
        private static string ExtractMerchant(string content, string fallback)
        {
            if (string.IsNullOrWhiteSpace(content)) return fallback;

            // Xóa các tiền tố phổ biến của MB Bank / ngân hàng
            var cleaned = content
                .Replace("MBCT", "").Replace("MBCKT", "")
                .Replace("Chuyen khoan", "").Replace("Chuyen tien", "")
                .Replace("Chuyển khoản", "").Replace("Chuyển tiền", "")
                .Replace("Nhan tien", "").Replace("Nhận tiền", "")
                .Replace("qua vi", "").Replace("qua ví", "")
                .Replace("BankAPINotify", "").Replace("FT", "")
                .Trim();

            // Xóa mã giao dịch dạng số dài
            cleaned = System.Text.RegularExpressions.Regex.Replace(
                cleaned, @"\b\d{6,}\b", "").Trim();

            // Lấy phần đầu có nghĩa, tối đa 50 ký tự
            if (cleaned.Length > 3)
            {
                // Capitalize
                cleaned = cleaned[0..Math.Min(50, cleaned.Length)].Trim();
                if (cleaned.Length > 0)
                    return char.ToUpper(cleaned[0]) + cleaned[1..];
            }

            return fallback;
        }

        /// <summary>Kiểm tra string có chứa bất kỳ keyword nào không.</summary>
        private static bool Contains(string source, params string[] keywords)
            => keywords.Any(k => source.Contains(k, StringComparison.OrdinalIgnoreCase));

        // ── Helpers ───────────────────────────────────────────────────────────

        private static BankAccountDto ToDto(BankAccount a) => new(
            Id:                    a.Id!,
            UserId:                a.UserId,
            BankName:              a.BankName,
            AccountNumberMasked:   MaskAccount(a.AccountNumber),
            AccountHolder:         a.AccountHolder,
            Balance:               a.Balance,
            Status:                a.Status,
            CreatedAt:             a.CreatedAt,
            LastSyncAt:            a.LastSyncAt
        );

        /// <summary>Che số tài khoản: "123456789" → "**** 6789"</summary>
        private static string MaskAccount(string number)
        {
            if (string.IsNullOrEmpty(number) || number.Length < 4)
                return number;
            return "**** " + number[^4..];
        }

        private static DateTime ParseDate(string? dateStr)
        {
            if (string.IsNullOrEmpty(dateStr)) return DateTime.UtcNow;
            return DateTime.TryParse(dateStr, out var dt) ? dt : DateTime.UtcNow;
        }
    }

    // ── SePay Webhook Payload ─────────────────────────────────────────────────

    public class SePayWebhookPayload
    {
        public long   Id              { get; set; }
        public string? Gateway        { get; set; }
        public string? TransactionDate{ get; set; }
        public string? AccountNumber  { get; set; }
        public string? SubAccount     { get; set; }
        public string? Code           { get; set; }
        public string? Content        { get; set; }
        /// <summary>"in" = tiền vào, "out" = tiền ra</summary>
        public string? TransferType   { get; set; }
        public double  TransferAmount { get; set; }
        /// <summary>Số dư sau giao dịch</summary>
        public double  Accumulated    { get; set; }
        public string? ReferenceCode  { get; set; }
        public string? Description    { get; set; }
    }
}
