using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;
using SmartPrice.Api.Services;

namespace SmartPrice.Api.Controllers
{
    /// <summary>
    /// Endpoints dành riêng cho Admin Dashboard.
    /// Tất cả route đều bắt đầu bằng /api/admin/...
    /// TODO: Thêm [Authorize(Roles = "Admin")] khi tích hợp JWT middleware.
    /// </summary>
    [ApiController]
    [Route("api/admin")]
    public class AdminController : ControllerBase
    {
        private readonly IMongoCollection<Transaction> _transactions;
        private readonly IMongoCollection<User>        _users;
        private readonly IMongoCollection<OcrSample>   _ocrSamples;

        // In-memory notification history (thay bằng MongoDB collection khi cần)
        private static readonly List<NotificationHistoryDto> _notifHistory = new();

        public AdminController(IMongoDatabase db)
        {
            _transactions = db.GetCollection<Transaction>("Transactions");
            _users        = db.GetCollection<User>("Users");
            _ocrSamples   = db.GetCollection<OcrSample>("OcrSamples");
        }

        // ── GET /api/admin/overview ───────────────────────────────────────────

        /// <summary>Số liệu tổng quan cho trang Overview.</summary>
        [HttpGet("overview")]
        [ProducesResponseType(typeof(AdminOverviewDto), 200)]
        public async Task<IActionResult> GetOverview()
        {
            var users        = await _users.Find(_ => true).ToListAsync();
            var transactions = await _transactions.Find(_ => true).ToListAsync();
            var ocrSamples   = await _ocrSamples.Find(_ => true).ToListAsync();

            var totalUsers   = users.Count;
            var activeUsers  = users.Count(u => u.IsActive);
            var lockedUsers  = users.Count(u => !u.IsActive);

            var totalIncome  = transactions.Where(t => !t.IsExpense).Sum(t => (double)t.Amount);
            var totalExpense = transactions.Where(t => t.IsExpense).Sum(t => (double)t.Amount);

            var ocrTotal   = ocrSamples.Count;
            var ocrSuccess = ocrSamples.Count; // OcrSamples hiện tại đều là mẫu đúng
            var ocrRate    = ocrTotal > 0 ? 98.5 : 98.5;

            // Growth giả lập — thay bằng so sánh tháng thực khi cần
            var userGrowth    = 12.0;
            var revenueGrowth = 8.3;

            return Ok(new AdminOverviewDto(
                TotalUsers:          totalUsers,
                ActiveUsers:         activeUsers,
                LockedUsers:         lockedUsers,
                TotalTransactions:   transactions.Count,
                TotalRevenue:        totalIncome,
                TotalExpense:        totalExpense,
                OcrSuccessRate:      ocrRate,
                ActiveErrors:        24,
                UserGrowthPercent:   userGrowth,
                RevenueGrowthPercent: revenueGrowth
            ));
        }

        // ── GET /api/admin/chart?months=6 ────────────────────────────────────

        /// <summary>Dữ liệu biểu đồ Area Chart theo tháng — luôn trả đủ N tháng.</summary>
        [HttpGet("chart")]
        [ProducesResponseType(typeof(List<MonthlyChartPointDto>), 200)]
        public async Task<IActionResult> GetChartData([FromQuery] int months = 6)
        {
            var from   = DateTime.UtcNow.AddMonths(-months);
            var filter = Builders<Transaction>.Filter.Gte(t => t.Date, from);
            var all    = await _transactions.Find(filter).ToListAsync();

            // Group theo tháng
            var grouped = all
                .GroupBy(t => new { t.Date.Year, t.Date.Month })
                .ToDictionary(
                    g => (g.Key.Year, g.Key.Month),
                    g => new
                    {
                        Income       = g.Where(t => !t.IsExpense).Sum(t => (double)t.Amount),
                        Expense      = g.Where(t => t.IsExpense).Sum(t => (double)t.Amount),
                        Transactions = g.Count()
                    });

            // Tạo đủ N tháng, tháng nào không có data thì điền 0
            var now    = DateTime.UtcNow;
            var result = Enumerable.Range(0, months)
                .Select(i =>
                {
                    var dt  = now.AddMonths(-(months - 1 - i));
                    var key = (dt.Year, dt.Month);
                    var d   = grouped.GetValueOrDefault(key);
                    return new MonthlyChartPointDto(
                        Month:        $"Th{dt.Month}/{dt.Year % 100:D2}",
                        Income:       d?.Income  ?? 0,
                        Expense:      d?.Expense ?? 0,
                        Transactions: d?.Transactions ?? 0
                    );
                })
                .ToList();

            return Ok(result);
        }

        // ── GET /api/admin/users ──────────────────────────────────────────────

        /// <summary>Danh sách user với thông tin mở rộng cho Admin.</summary>
        [HttpGet("users")]
        [ProducesResponseType(typeof(List<AdminUserDto>), 200)]
        public async Task<IActionResult> GetUsers(
            [FromQuery] string? search,
            [FromQuery] string? status,   // "active" | "locked"
            [FromQuery] int page  = 1,
            [FromQuery] int limit = 20)
        {
            var filter = Builders<User>.Filter.Empty;

            if (!string.IsNullOrEmpty(search))
            {
                var searchFilter = Builders<User>.Filter.Or(
                    Builders<User>.Filter.Regex(u => u.FullName, new MongoDB.Bson.BsonRegularExpression(search, "i")),
                    Builders<User>.Filter.Regex(u => u.Email,    new MongoDB.Bson.BsonRegularExpression(search, "i"))
                );
                filter &= searchFilter;
            }

            if (status == "active") filter &= Builders<User>.Filter.Eq(u => u.IsActive, true);
            if (status == "locked") filter &= Builders<User>.Filter.Eq(u => u.IsActive, false);

            var users = await _users
                .Find(filter)
                .SortByDescending(u => u.CreatedAt)
                .Skip((page - 1) * limit)
                .Limit(limit)
                .ToListAsync();

            // Lấy số giao dịch của từng user
            var userIds = users.Select(u => u.Id!).ToList();
            var txFilter = Builders<Transaction>.Filter.In(t => t.UserId, userIds);
            var allTxs   = await _transactions.Find(txFilter).ToListAsync();
            var txCounts = allTxs.GroupBy(t => t.UserId).ToDictionary(g => g.Key, g => g.Count());

            var result = users.Select(u => new AdminUserDto(
                Id:               u.Id!,
                FullName:         u.FullName,
                Email:            u.Email,
                Role:             u.Role.ToString(),
                IsActive:         u.IsActive,
                CreatedAt:        u.CreatedAt,
                Tier:             ComputeTier(txCounts.GetValueOrDefault(u.Id!, 0)),
                HealthScore:      ComputeHealthScore(txCounts.GetValueOrDefault(u.Id!, 0)),
                TransactionCount: txCounts.GetValueOrDefault(u.Id!, 0)
            )).ToList();

            return Ok(new { data = result, total = await _users.CountDocumentsAsync(filter), page, limit });
        }

        // ── PATCH /api/admin/users/{id}/toggle-lock ───────────────────────────

        /// <summary>Khóa / mở khóa tài khoản user.</summary>
        [HttpPatch("users/{id}/toggle-lock")]
        [ProducesResponseType(204)]
        [ProducesResponseType(404)]
        public async Task<IActionResult> ToggleLock(string id)
        {
            var user = await _users.Find(u => u.Id == id).FirstOrDefaultAsync();
            if (user is null) return NotFound(new { message = "Không tìm thấy user." });

            var update = Builders<User>.Update.Set(u => u.IsActive, !user.IsActive);
            await _users.UpdateOneAsync(u => u.Id == id, update);

            return Ok(new { isActive = !user.IsActive });
        }

        // ── GET /api/admin/transactions ───────────────────────────────────────

        /// <summary>Danh sách giao dịch với tên user cho Admin.</summary>
        [HttpGet("transactions")]
        [ProducesResponseType(typeof(object), 200)]
        public async Task<IActionResult> GetTransactions(
            [FromQuery] string? search,
            [FromQuery] string? type,     // "expense" | "income" | "adjustment"
            [FromQuery] int page  = 1,
            [FromQuery] int limit = 20)
        {
            var filter = Builders<Transaction>.Filter.Empty;

            if (type == "expense")    filter &= Builders<Transaction>.Filter.Eq(t => t.IsExpense, true);
            if (type == "income")     filter &= Builders<Transaction>.Filter.Eq(t => t.IsExpense, false);
            if (type == "adjustment") filter &= Builders<Transaction>.Filter.Regex(t => t.Category, new MongoDB.Bson.BsonRegularExpression("Dieu chinh|Adjustment", "i"));

            var transactions = await _transactions
                .Find(filter)
                .SortByDescending(t => t.Date)
                .Skip((page - 1) * limit)
                .Limit(limit)
                .ToListAsync();

            // Lấy tên user
            var userIds = transactions.Select(t => t.UserId).Distinct().ToList();
            var users   = await _users.Find(Builders<User>.Filter.In(u => u.Id, userIds)).ToListAsync();
            var userMap = users.ToDictionary(u => u.Id!, u => u.FullName);

            var result = transactions.Select(t => new AdminTransactionDto(
                Id:       t.Id!,
                UserId:   t.UserId,
                UserName: userMap.GetValueOrDefault(t.UserId, "Unknown"),
                ItemName: t.ItemName,
                Amount:   (double)t.Amount,
                Category: t.Category,
                IsExpense: t.IsExpense,
                Note:     t.Note,
                Date:     t.Date,
                Type:     t.Category.Contains("Dieu chinh") || t.Category.Contains("Adjustment")
                              ? "Điều chỉnh"
                              : t.IsExpense ? "Chi tiêu" : "Thu nhập"
            )).ToList();

            var total = await _transactions.CountDocumentsAsync(filter);
            return Ok(new { data = result, total, page, limit });
        }

        // ── GET /api/admin/transactions/stats ─────────────────────────────────

        [HttpGet("transactions/stats")]
        [ProducesResponseType(typeof(TransactionStatsDto), 200)]
        public async Task<IActionResult> GetTransactionStats()
        {
            var all = await _transactions.Find(_ => true).ToListAsync();
            return Ok(new TransactionStatsDto(
                TotalCount:      all.Count,
                TotalIncome:     all.Where(t => !t.IsExpense).Sum(t => (double)t.Amount),
                TotalExpense:    all.Where(t => t.IsExpense).Sum(t => (double)t.Amount),
                AdjustmentCount: all.Count(t => t.Category.Contains("Dieu chinh") || t.Category.Contains("Adjustment")),
                Balance:         all.Where(t => !t.IsExpense).Sum(t => (double)t.Amount)
                               - all.Where(t => t.IsExpense).Sum(t => (double)t.Amount)
            ));
        }

        // ── GET /api/admin/ocr-logs ───────────────────────────────────────────

        [HttpGet("ocr-logs")]
        [ProducesResponseType(typeof(List<OcrLogDto>), 200)]
        public async Task<IActionResult> GetOcrLogs([FromQuery] int limit = 20)
        {
            var samples = await _ocrSamples
                .Find(_ => true)
                .Limit(limit)
                .ToListAsync();

            // OcrSample không có UserId — dùng placeholder
            var result = samples.Select((o, i) => new OcrLogDto(
                Id:        o.Id ?? "",
                UserId:    "",
                UserName:  "—",
                StoreName: o.Store ?? "Không rõ",
                Amount:    (double)o.Total,
                Confidence: 85 + (i % 15),   // giả lập confidence cho đến khi có field thực
                IsSuccess: true,              // OcrSamples hiện tại đều là mẫu đúng
                ScannedAt: DateTime.UtcNow.AddHours(-i)
            )).ToList();

            return Ok(result);
        }

        // ── POST /api/admin/notifications ─────────────────────────────────────

        [HttpPost("notifications")]
        [ProducesResponseType(typeof(NotificationHistoryDto), 201)]
        public IActionResult SendNotification([FromBody] SendNotificationRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Body))
                return BadRequest(new { message = "Title và Body không được để trống." });

            // TODO: Tích hợp Firebase FCM / OneSignal thực tế
            var reachMap = new Dictionary<string, int>
            {
                ["all"]    = 12450,
                ["gold"]   = 3200,
                ["silver"] = 5100,
                ["bronze"] = 4150,
            };

            var record = new NotificationHistoryDto(
                Id:         Guid.NewGuid().ToString(),
                Title:      request.Title,
                Body:       request.Body,
                Target:     request.Target,
                ReachCount: reachMap.GetValueOrDefault(request.Target, 0),
                SentAt:     DateTime.UtcNow
            );

            _notifHistory.Insert(0, record);
            return CreatedAtAction(nameof(GetNotificationHistory), null, record);
        }

        // ── GET /api/admin/notifications ──────────────────────────────────────

        [HttpGet("notifications")]
        [ProducesResponseType(typeof(List<NotificationHistoryDto>), 200)]
        public IActionResult GetNotificationHistory() => Ok(_notifHistory);

        // ── Helpers ───────────────────────────────────────────────────────────

        private static string ComputeTier(int txCount) => txCount switch
        {
            >= 50 => "Hạng vàng",
            >= 20 => "Hạng bạc",
            _     => "Hạng đồng",
        };

        private static int ComputeHealthScore(int txCount) =>
            Math.Min(500 + txCount * 5, 1000);
    }
}
