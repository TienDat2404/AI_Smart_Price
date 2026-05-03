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
    [Route("api/invoice")]   // explicit route — không dùng [controller] để tránh nhầm
    public class InvoiceController : ControllerBase
    {
        private readonly IMongoCollection<OcrSample> _ocrCollection;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<InvoiceController> _logger;
        private readonly IHttpClientFactory _httpFactory;

        // Python AI Engine endpoint
        private const string AiEngineUrl = "http://localhost:8000/parse/image";

        private string UploadsPath => Path.Combine(_env.ContentRootPath, "Uploads");

        public InvoiceController(
            IMongoDatabase db,
            IWebHostEnvironment env,
            ILogger<InvoiceController> logger,
            IHttpClientFactory httpFactory)
        {
            _ocrCollection = db.GetCollection<OcrSample>("OcrSamples");
            _env           = env;
            _logger        = logger;
            _httpFactory   = httpFactory;
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
                return UnprocessableEntity(new
                {
                    message  = "Khong the nhan dien hoa don nay, vui long thu lai hoac nhap tay.",
                    fileName = fileName,
                });
            }

            // ── Lưu kết quả vào MongoDB ───────────────────────────────────────
            await _ocrCollection.InsertOneAsync(new OcrSample
            {
                InvoiceId = result.InvoiceId,
                Store     = result.StoreName,
                Total     = (long)result.TotalAmount,
                Date      = result.Date,
            });

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
                form.Add(new StreamContent(fileStream), "image", Path.GetFileName(filePath));

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

                return new InvoiceScanResponse
                {
                    InvoiceId   = $"INV-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
                    StoreName   = GetString(doc, "store", "item") ?? "Khong ro",
                    TotalAmount = GetDouble(doc, "total", "price"),
                    Date        = GetString(doc, "date") ?? DateTime.Now.ToString("dd/MM/yyyy"),
                    Category    = GetString(doc, "category") ?? "Khac",
                    Confidence  = GetDouble(doc, "confidence"),
                    FileName    = fileName,
                };
            }
            catch (HttpRequestException ex)
            {
                // AI Engine chưa chạy — dùng stub để không block demo
                _logger.LogWarning("AI Engine unreachable ({Message}), using stub response.", ex.Message);
                return BuildStubResponse(fileName);
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

        /// <summary>Stub response khi AI Engine chưa sẵn sàng.</summary>
        private static InvoiceScanResponse BuildStubResponse(string fileName) => new()
        {
            InvoiceId   = $"INV-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
            StoreName   = "WinMart (Stub)",
            TotalAmount = 450000,
            Date        = DateTime.Now.ToString("dd/MM/yyyy"),
            Category    = "Mua sam",
            Confidence  = 0.75,
            FileName    = fileName,
        };
    }

    // ── Response DTO ──────────────────────────────────────────────────────────

    public class InvoiceScanResponse
    {
        public string InvoiceId   { get; set; } = string.Empty;
        public string StoreName   { get; set; } = string.Empty;
        public double TotalAmount { get; set; }
        public string Date        { get; set; } = string.Empty;
        public string Category    { get; set; } = string.Empty;
        public double Confidence  { get; set; }
        public string FileName    { get; set; } = string.Empty;
    }
}
