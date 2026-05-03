using System.Text.Json;
using MongoDB.Driver;
using SmartPrice.Api.Models;
using SmartPrice.Api.Services;

namespace SmartPrice.Api.Services
{
    /// <summary>
    /// Tự động seed dữ liệu từ các file JSON trong thư mục /datasets/
    /// khi collection tương ứng đang trống.
    /// </summary>
    public class DataSeeder
    {
        private readonly IMongoDatabase _db;
        private readonly ILogger<DataSeeder> _logger;
        private readonly string _datasetsPath;

        private static readonly JsonSerializerOptions _jsonOptions = new()
        {
            PropertyNameCaseInsensitive = true,
        };

        public DataSeeder(IMongoDatabase db, ILogger<DataSeeder> logger, IWebHostEnvironment env)
        {
            _db = db;
            _logger = logger;

            // ── Tìm thư mục datasets/ ─────────────────────────────────────────
            // Cấu trúc thực tế:
            //   SmartPrice_Project/          ← đây là root cần tìm
            //     datasets/
            //     backend_api/
            //       SmartPrice.Api/          ← ContentRootPath khi chạy dotnet run
            //
            // Vậy cần đi lên 2 cấp từ ContentRootPath:
            //   ContentRootPath/../..  =  SmartPrice_Project/
            //
            // Nhưng khi publish hoặc chạy từ bin/Debug/net8.0/, cần thêm fallback.

            var contentRoot = env.ContentRootPath;

            // Thử các vị trí theo thứ tự ưu tiên
            var candidates = new[]
            {
                // Chạy từ SmartPrice.Api/ (dotnet run)
                Path.GetFullPath(Path.Combine(contentRoot, "..", "..", "datasets")),
                // Chạy từ bin/Debug/net8.0/ (dotnet run --project hoặc IDE)
                Path.GetFullPath(Path.Combine(contentRoot, "..", "..", "..", "..", "datasets")),
                // Fallback: cùng cấp với executable
                Path.GetFullPath(Path.Combine(contentRoot, "datasets")),
            };

            _datasetsPath = candidates.FirstOrDefault(Directory.Exists)
                            ?? candidates[0]; // dùng candidate đầu tiên nếu không tìm thấy

            Console.WriteLine($"[DataSeeder] ContentRootPath  : {contentRoot}");
            Console.WriteLine($"[DataSeeder] datasets/ đã chọn: {_datasetsPath}");
            Console.WriteLine($"[DataSeeder] Thư mục tồn tại  : {Directory.Exists(_datasetsPath)}");
        }

        /// <summary>
        /// Chạy toàn bộ quá trình seed. Gọi từ Program.cs khi khởi động.
        /// </summary>
        public async Task SeedAsync()
        {
            Console.WriteLine("[DataSeeder] ========== BẮT ĐẦU SEED ==========");

            try
            {
                await SeedAdminUserAsync();   // ← seed admin trước
                await SeedTransactionsAsync();
                await SeedNlpSamplesAsync();
                await SeedFinanceSeriesAsync();
                await SeedOcrSamplesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ LỖI NGHIÊM TRỌNG: {ex.GetType().Name}");
                Console.WriteLine($"[DataSeeder] Message : {ex.Message}");
                Console.WriteLine($"[DataSeeder] StackTrace:\n{ex.StackTrace}");
                _logger.LogError(ex, "DataSeeder gặp lỗi không xử lý được.");
                // Không re-throw để app vẫn khởi động được
            }

            Console.WriteLine("[DataSeeder] ========== HOÀN TẤT SEED ==========");
        }

        // ── Admin User ────────────────────────────────────────────────────────

        private async Task SeedAdminUserAsync()
        {
            Console.WriteLine("[DataSeeder] --- Kiểm tra Admin User ---");
            try
            {
                var userService = new UserService(_db);
                await userService.EnsureAdminAsync(
                    email:    "admin@gmail.com",
                    password: "admin123",
                    fullName: "Administrator"
                );
                Console.WriteLine("[DataSeeder] ✅ Admin user sẵn sàng.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ Admin seed FAILED: {ex.Message}");
                // Không throw — app vẫn chạy được dù seed admin thất bại
            }
        }

        // ── Transactions ──────────────────────────────────────────────────────

        private async Task SeedTransactionsAsync()
        {
            Console.WriteLine("[DataSeeder] --- Kiểm tra Transactions ---");
            try
            {
                var collection = _db.GetCollection<Transaction>("Transactions");
                var count = await collection.CountDocumentsAsync(FilterDefinition<Transaction>.Empty);
                Console.WriteLine($"[DataSeeder] Transactions hiện có: {count} document");

                if (count > 0)
                {
                    Console.WriteLine("[DataSeeder] Transactions: Đã có dữ liệu, bỏ qua seed.");
                    return;
                }

                var samples = new List<Transaction>
                {
                    new() { ItemName = "Phở bò buổi sáng",  Amount = 45000,   Date = DateTime.Now.AddDays(-6), Category = "Ăn uống",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Grab đi làm",        Amount = 25000,   Date = DateTime.Now.AddDays(-6), Category = "Di chuyển", IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Siêu thị VinMart",   Amount = 120000,  Date = DateTime.Now.AddDays(-5), Category = "Mua sắm",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Lương tháng",        Amount = 5000000, Date = DateTime.Now.AddDays(-5), Category = "Thu nhập",  IsExpense = false, UserId = "user_01" },
                    new() { ItemName = "Cơm văn phòng",      Amount = 85000,   Date = DateTime.Now.AddDays(-4), Category = "Ăn uống",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Xem phim CGV",       Amount = 200000,  Date = DateTime.Now.AddDays(-4), Category = "Giải trí",  IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Bún bò Huế",         Amount = 60000,   Date = DateTime.Now.AddDays(-3), Category = "Ăn uống",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Khám bác sĩ",        Amount = 350000,  Date = DateTime.Now.AddDays(-3), Category = "Sức khỏe",  IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Đổ xăng xe máy",     Amount = 50000,   Date = DateTime.Now.AddDays(-2), Category = "Di chuyển", IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Freelance thiết kế", Amount = 500000,  Date = DateTime.Now.AddDays(-2), Category = "Thu nhập",  IsExpense = false, UserId = "user_01" },
                    new() { ItemName = "Lẩu với bạn bè",     Amount = 75000,   Date = DateTime.Now.AddDays(-1), Category = "Ăn uống",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Quần áo sale",       Amount = 180000,  Date = DateTime.Now.AddDays(-1), Category = "Mua sắm",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Bánh mì ốp la",      Amount = 35000,   Date = DateTime.Now,             Category = "Ăn uống",   IsExpense = true,  UserId = "user_01" },
                    new() { ItemName = "Grab về nhà",        Amount = 30000,   Date = DateTime.Now,             Category = "Di chuyển", IsExpense = true,  UserId = "user_01" },
                };

                await collection.InsertManyAsync(samples);
                Console.WriteLine($"[DataSeeder] ✅ Transactions: Đã seed {samples.Count} bản ghi.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ Transactions FAILED: {ex.Message}");
                throw;
            }
        }

        // ── NLP Samples ───────────────────────────────────────────────────────

        private async Task SeedNlpSamplesAsync()
        {
            Console.WriteLine("[DataSeeder] --- Kiểm tra NlpSamples ---");
            try
            {
                var collection = _db.GetCollection<NlpSample>("NlpSamples");
                var count = await collection.CountDocumentsAsync(FilterDefinition<NlpSample>.Empty);
                Console.WriteLine($"[DataSeeder] NlpSamples hiện có: {count} document");

                if (count > 0)
                {
                    Console.WriteLine("[DataSeeder] NlpSamples: Đã có dữ liệu, bỏ qua seed.");
                    return;
                }

                var filePath = Path.Combine(_datasetsPath, "nlp_data.json");
                Console.WriteLine($"[DataSeeder] Đọc file: {filePath}");
                Console.WriteLine($"[DataSeeder] File tồn tại: {File.Exists(filePath)}");

                if (!File.Exists(filePath))
                {
                    Console.WriteLine($"[DataSeeder] ⚠️  NlpSamples: Không tìm thấy file, bỏ qua.");
                    return;
                }

                var json = await File.ReadAllTextAsync(filePath);
                var root = JsonSerializer.Deserialize<NlpJsonRoot>(json, _jsonOptions);

                Console.WriteLine($"[DataSeeder] Deserialize thành công: {root?.Data?.Count ?? 0} records");

                if (root?.Data == null || root.Data.Count == 0)
                {
                    Console.WriteLine("[DataSeeder] ⚠️  NlpSamples: JSON rỗng hoặc sai cấu trúc.");
                    return;
                }

                var docs = root.Data.Select(d => new NlpSample
                {
                    NlpId    = d.Id,
                    RawText  = d.RawText,
                    Intent   = d.Intent,
                    Entities = new NlpEntities
                    {
                        Item     = d.Entities.Item,
                        Price    = d.Entities.Price,
                        Category = d.Entities.Category,
                    },
                }).ToList();

                await collection.InsertManyAsync(docs);
                Console.WriteLine($"[DataSeeder] ✅ NlpSamples: Đã seed {docs.Count} bản ghi.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ NlpSamples FAILED: {ex.Message}");
                throw;
            }
        }

        // ── Finance Series ────────────────────────────────────────────────────

        private async Task SeedFinanceSeriesAsync()
        {
            Console.WriteLine("[DataSeeder] --- Kiểm tra FinanceSeries ---");
            try
            {
                var collection = _db.GetCollection<FinanceSeries>("FinanceSeries");
                var count = await collection.CountDocumentsAsync(FilterDefinition<FinanceSeries>.Empty);
                Console.WriteLine($"[DataSeeder] FinanceSeries hiện có: {count} document");

                if (count > 0)
                {
                    Console.WriteLine("[DataSeeder] FinanceSeries: Đã có dữ liệu, bỏ qua seed.");
                    return;
                }

                var filePath = Path.Combine(_datasetsPath, "finance_series.json");
                Console.WriteLine($"[DataSeeder] Đọc file: {filePath}");
                Console.WriteLine($"[DataSeeder] File tồn tại: {File.Exists(filePath)}");

                if (!File.Exists(filePath))
                {
                    Console.WriteLine("[DataSeeder] ⚠️  FinanceSeries: Không tìm thấy file, bỏ qua.");
                    return;
                }

                var json = await File.ReadAllTextAsync(filePath);
                var root = JsonSerializer.Deserialize<FinanceJsonRoot>(json, _jsonOptions);

                Console.WriteLine($"[DataSeeder] Deserialize thành công: {root?.Data?.Count ?? 0} records");

                if (root?.Data == null || root.Data.Count == 0)
                {
                    Console.WriteLine("[DataSeeder] ⚠️  FinanceSeries: JSON rỗng hoặc sai cấu trúc.");
                    return;
                }

                var docs = root.Data.Select(d => new FinanceSeries
                {
                    Date   = d.Date,
                    Amount = d.Amount,
                }).ToList();

                await collection.InsertManyAsync(docs);
                Console.WriteLine($"[DataSeeder] ✅ FinanceSeries: Đã seed {docs.Count} bản ghi.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ FinanceSeries FAILED: {ex.Message}");
                throw;
            }
        }

        // ── OCR Samples ───────────────────────────────────────────────────────

        private async Task SeedOcrSamplesAsync()
        {
            Console.WriteLine("[DataSeeder] --- Kiểm tra OcrSamples ---");
            try
            {
                var collection = _db.GetCollection<OcrSample>("OcrSamples");
                var count = await collection.CountDocumentsAsync(FilterDefinition<OcrSample>.Empty);
                Console.WriteLine($"[DataSeeder] OcrSamples hiện có: {count} document");

                if (count > 0)
                {
                    Console.WriteLine("[DataSeeder] OcrSamples: Đã có dữ liệu, bỏ qua seed.");
                    return;
                }

                var filePath = Path.Combine(_datasetsPath, "ocr_samples.json");
                Console.WriteLine($"[DataSeeder] Đọc file: {filePath}");
                Console.WriteLine($"[DataSeeder] File tồn tại: {File.Exists(filePath)}");

                if (!File.Exists(filePath))
                {
                    Console.WriteLine("[DataSeeder] ⚠️  OcrSamples: Không tìm thấy file, bỏ qua.");
                    return;
                }

                var json = await File.ReadAllTextAsync(filePath);
                var root = JsonSerializer.Deserialize<OcrJsonRoot>(json, _jsonOptions);

                Console.WriteLine($"[DataSeeder] Deserialize thành công: {root?.Data?.Count ?? 0} records");

                if (root?.Data == null || root.Data.Count == 0)
                {
                    Console.WriteLine("[DataSeeder] ⚠️  OcrSamples: JSON rỗng hoặc sai cấu trúc.");
                    return;
                }

                var docs = root.Data.Select(d => new OcrSample
                {
                    InvoiceId = d.InvoiceId,
                    Store     = d.Store,
                    Total     = d.Total,
                    Date      = d.Date,
                }).ToList();

                await collection.InsertManyAsync(docs);
                Console.WriteLine($"[DataSeeder] ✅ OcrSamples: Đã seed {docs.Count} bản ghi.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DataSeeder] ❌ OcrSamples FAILED: {ex.Message}");
                throw;
            }
        }

        // ── JSON DTOs ─────────────────────────────────────────────────────────

        private sealed class NlpJsonRoot
        {
            public List<NlpDataDto> Data { get; set; } = [];
        }

        private sealed class NlpDataDto
        {
            public int Id { get; set; }
            public string RawText { get; set; } = null!;
            public string Intent { get; set; } = null!;
            public NlpEntitiesDto Entities { get; set; } = null!;
        }

        private sealed class NlpEntitiesDto
        {
            public string Item { get; set; } = null!;
            public decimal Price { get; set; }
            public string Category { get; set; } = null!;
        }

        private sealed class FinanceJsonRoot
        {
            public List<FinanceDataDto> Data { get; set; } = [];
        }

        private sealed class FinanceDataDto
        {
            public string Date { get; set; } = null!;
            public long Amount { get; set; }
        }

        private sealed class OcrJsonRoot
        {
            public List<OcrDataDto> Data { get; set; } = [];
        }

        private sealed class OcrDataDto
        {
            public string InvoiceId { get; set; } = null!;
            public string Store { get; set; } = null!;
            public long Total { get; set; }
            public string Date { get; set; } = null!;
        }
    }
}
