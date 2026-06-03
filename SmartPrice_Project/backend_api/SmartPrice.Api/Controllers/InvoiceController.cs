using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    /// <summary>
    /// POST /api/invoice/scan
    /// Nhận ảnh hóa đơn từ Flutter → lưu Uploads/ → gửi Python AI Engine → trả kết quả OCR.
    /// </summary>
    [ApiController]
    [Route("api/invoice")]
    public class InvoiceController : ControllerBase
    {
        private readonly IMongoCollection<OcrSample>   _ocrCollection;
        private readonly IMongoCollection<SystemError> _errorCollection;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<InvoiceController> _logger;
        private readonly IHttpClientFactory _httpFactory;

        private const string AiEngineUrl = "http://localhost:8000/parse/image";

        private string UploadsPath => Path.Combine(_env.ContentRootPath, "Uploads");

        public InvoiceController(
            IMongoDatabase db,
            IWebHostEnvironment env,
            ILogger<InvoiceController> logger,
            IHttpClientFactory httpFactory)
        {
            _ocrCollection   = db.GetCollection<OcrSample>("OcrSamples");
            _errorCollection = db.GetCollection<SystemError>("SystemErrors");
            _env             = env;
            _logger          = logger;
            _httpFactory     = httpFactory;
        }

        // ── POST /api/invoice/scan ────────────────────────────────────────────

        [HttpPost("scan")]
        [Consumes("multipart/form-data")]
        [ProducesResponseType(typeof(InvoiceScanResponse), 200)]
        [ProducesResponseType(typeof(object), 422)]
        [ProducesResponseType(typeof(object), 400)]
        public async Task<IActionResult> Scan([FromForm] IFormFile? image)
        {
            // ── Validate ──────────────────────────────────────────────────────
            if (image == null || image.Length == 0)
                return BadRequest(new { message = "Vui long gui file anh hop le." });

            var ext = Path.GetExtension(image.FileName).ToLowerInvariant();
            if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp"))
                return BadRequest(new { message = "Chi chap nhan JPG, PNG, WEBP." });

            if (image.Length > 10 * 1024 * 1024)
                return BadRequest(new { message = "Kich thuoc anh khong duoc vuot qua 10MB." });

            // ── Lưu file vào Uploads/ ─────────────────────────────────────────
            Directory.CreateDirectory(UploadsPath);
            var fileName = $"{Guid.NewGuid():N}{ext}";
            var filePath = Path.Combine(UploadsPath, fileName);

            await using (var stream = System.IO.File.Create(filePath))
            {
                await image.CopyToAsync(stream);
            }
            _logger.LogInformation("Invoice saved: {FileName} ({Size} bytes)", fileName, image.Length);

            // ── Gọi Python AI Engine ──────────────────────────────────────────
            InvoiceScanResponse result;
            try
            {
                result = await CallAiEngineAsync(filePath, fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "OCR failed for {FileName}: {Message}", fileName, ex.Message);

                // Log lỗi vào SystemErrors để admin theo dõi
                await _errorCollection.InsertOneAsync(new SystemError
                {
                    Source     = "OCR",
                    Message    = $"OCR thất bại: {ex.Message} | file: {fileName}",
                    Level      = "error",
                    IsResolved = false,
                    OccurredAt = DateTime.UtcNow,
                });

                return UnprocessableEntity(new
                {
                    message  = "Khong the nhan dien hoa don nay, vui long thu lai hoac nhap tay.",
                    fileName = fileName,
                });
            }

            // ── Lưu kết quả vào MongoDB ───────────────────────────────────────
            await _ocrCollection.InsertOneAsync(new OcrSample
            {
                InvoiceId  = result.InvoiceId,
                Store      = result.StoreName,
                Total      = (long)result.TotalAmount,
                Date       = result.Date,
                Confidence = result.Confidence,
                IsSuccess  = result.Status != "failed" && result.TotalAmount > 0,
                Status     = result.Status,
                ScannedAt  = DateTime.UtcNow,
            });

            // Nếu AI trả về status "failed" — log warning
            if (result.Status == "failed")
            {
                await _errorCollection.InsertOneAsync(new SystemError
                {
                    Source     = "OCR",
                    Message    = $"Ảnh chất lượng thấp (conf={result.Confidence:P0}): {result.StoreName ?? fileName}",
                    Level      = "warning",
                    IsResolved = false,
                    OccurredAt = DateTime.UtcNow,
                });
            }

            return Ok(result);
        }

        // ── GET /api/invoice/uploads/{fileName} ───────────────────────────────

        [HttpGet("uploads/{fileName}")]
        public IActionResult GetUpload(string fileName)
        {
            var filePath = Path.Combine(UploadsPath, fileName);
            if (!System.IO.File.Exists(filePath)) return NotFound();
            var ext  = Path.GetExtension(fileName).TrimStart('.').ToLower();
            var mime = ext switch { "png" => "image/png", "webp" => "image/webp", _ => "image/jpeg" };
            return PhysicalFile(filePath, mime);
        }

        // ── AI Engine caller ──────────────────────────────────────────────────

        /// <summary>
        /// Gửi ảnh tới Python FastAPI OCR Engine.
        /// Nếu AI Engine chưa chạy → fallback về stub demo.
        /// </summary>
        private async Task<InvoiceScanResponse> CallAiEngineAsync(string filePath, string fileName)
        {
            try
            {
                var client = _httpFactory.CreateClient("AiEngine");

                await using var fileStream = System.IO.File.OpenRead(filePath);
                using var form = new MultipartFormDataContent();

                // Xác định MIME type từ extension để Python không từ chối
                var ext  = Path.GetExtension(filePath).TrimStart('.').ToLowerInvariant();
                var mime = ext switch {
                    "png"  => "image/png",
                    "webp" => "image/webp",
                    "bmp"  => "image/bmp",
                    _      => "image/jpeg"
                };
                var streamContent = new StreamContent(fileStream);
                streamContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(mime);
                form.Add(streamContent, "image", Path.GetFileName(filePath));

                _logger.LogInformation("Calling AI Engine: {Url}", AiEngineUrl);
                var response = await client.PostAsync(AiEngineUrl, form);

                if (!response.IsSuccessStatusCode)
                {
                    var errBody = await response.Content.ReadAsStringAsync();
                    _logger.LogWarning("AI Engine returned {Status}: {Body}", response.StatusCode, errBody);
                    throw new InvalidOperationException($"AI Engine error: {response.StatusCode}");
                }

                var json = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("AI Engine response: {Json}", json);

                // Parse kết quả từ Python AI Engine
                // Expected JSON: { "item": "...", "price": 0, "category": "..." }
                // hoặc extended: { "store": "...", "total": 0, "date": "...", "category": "..." }
                var doc = JsonSerializer.Deserialize<JsonElement>(json);

                // Kiểm tra status từ Python — "failed" hoặc "low_confidence"
                var status = GetString(doc, "status") ?? "success";

                if (status == "failed")
                {
                    // Ảnh quá mờ, OCR không đọc được — trả về response với flag để Flutter hiển thị retake UI
                    var suggestions = new List<string>();
                    if (doc.TryGetProperty("suggestions", out var sugsEl) && sugsEl.ValueKind == JsonValueKind.Array)
                        foreach (var s in sugsEl.EnumerateArray())
                            if (s.ValueKind == JsonValueKind.String) suggestions.Add(s.GetString()!);

                    return new InvoiceScanResponse
                    {
                        InvoiceId   = $"INV-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
                        StoreName   = "Không rõ",
                        TotalAmount = 0,
                        Date        = DateTime.Now.ToString("dd/MM/yyyy"),
                        Category    = "Khác",
                        Confidence  = GetDouble(doc, "confidence"),
                        FileName    = fileName,
                        Status      = "failed",
                        Suggestions = suggestions,
                        RawText     = GetString(doc, "raw_text") ?? "",
                    };
                }

                return new InvoiceScanResponse
                {
                    InvoiceId   = $"INV-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
                    StoreName   = SanitizeStoreName(GetString(doc, "store", "item") ?? "Không rõ"),
                    TotalAmount = GetDouble(doc, "total", "price"),
                    Date        = GetString(doc, "date") ?? DateTime.Now.ToString("dd/MM/yyyy"),
                    Category    = GetString(doc, "category") ?? "Khác",
                    Confidence  = GetDouble(doc, "confidence"),
                    FileName    = fileName,
                    Status      = status,
                    Suggestions = new List<string>(),
                    RawText     = "",
                };
            }
            catch (HttpRequestException ex)
            {
                // AI Engine chưa chạy — báo lỗi rõ ràng thay vì trả dữ liệu giả
                _logger.LogWarning("AI Engine unreachable ({Message}). Vui lòng chạy: uvicorn main:app --port 8000", ex.Message);
                throw new InvalidOperationException(
                    "AI Engine (Python) chưa chạy. Vui lòng khởi động: cd ai_service && uvicorn main:app --port 8000"
                );
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        private static string? GetString(JsonElement doc, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (doc.TryGetProperty(key, out var val) && val.ValueKind == JsonValueKind.String)
                    return val.GetString();
            }
            return null;
        }

        private static double GetDouble(JsonElement doc, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (doc.TryGetProperty(key, out var val))
                {
                    if (val.ValueKind == JsonValueKind.Number) return val.GetDouble();
                    if (val.ValueKind == JsonValueKind.String &&
                        double.TryParse(val.GetString(), out var d)) return d;
                }
            }
            return 0;
        }

        /// <summary>Làm sạch tên cửa hàng — trả về "Không rõ" nếu trông như OCR noise hoặc tiêu đề hóa đơn.</summary>
        private static string SanitizeStoreName(string name)
        {
            if (string.IsNullOrWhiteSpace(name)) return "Không rõ";
            var trimmed = name.Trim();
            if (trimmed.Length < 3) return "Không rõ";

            // Bỏ qua tiêu đề hóa đơn phổ biến
            var lower = trimmed.ToLowerInvariant();
            var invoiceTitles = new[] {
                "hóa đơn", "hoa don", "invoice", "receipt", "bill",
                "bán lẻ", "ban le", "bán hàng", "ban hang",
                "không rõ", "khong ro"
            };
            if (invoiceTitles.Any(t => lower.Contains(t))) return "Không rõ";

            // Tỷ lệ chữ cái hợp lệ < 40% → noise
            var letters = trimmed.Count(c => char.IsLetter(c));
            if ((double)letters / trimmed.Length < 0.4) return "Không rõ";

            // Kết thúc bằng dấu ":" thường là nhãn (Thu ngân:, Ngày:)
            if (trimmed.EndsWith(":")) return "Không rõ";

            return trimmed;
        }

        // ── Response DTO ──────────────────────────────────────────────────────────
    }  // end InvoiceController

    public class InvoiceScanResponse
    {
        public string InvoiceId   { get; set; } = string.Empty;
        public string StoreName   { get; set; } = string.Empty;
        public double TotalAmount { get; set; }
        public string Date        { get; set; } = string.Empty;
        public string Category    { get; set; } = string.Empty;
        public double Confidence  { get; set; }
        public string FileName    { get; set; } = string.Empty;
        /// <summary>"success" | "low_confidence" | "failed"</summary>
        public string Status      { get; set; } = "success";
        public List<string> Suggestions { get; set; } = new();
        public string RawText     { get; set; } = string.Empty;
    }
}
