using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OcrSamplesController : ControllerBase
    {
        private readonly IMongoCollection<OcrSample> _collection;

        public OcrSamplesController(IMongoDatabase db)
        {
            _collection = db.GetCollection<OcrSample>("OcrSamples");
        }

        // GET api/ocrsamples
        [HttpGet]
        public async Task<ActionResult<List<OcrSample>>> GetAll(
            [FromQuery] string? store,
            [FromQuery] string? date,
            [FromQuery] long? minTotal,
            [FromQuery] long? maxTotal)
        {
            var builder = Builders<OcrSample>.Filter;
            var filter  = builder.Empty;

            if (!string.IsNullOrEmpty(store))
                filter &= builder.Regex(o => o.Store, new MongoDB.Bson.BsonRegularExpression(store, "i"));

            if (!string.IsNullOrEmpty(date))
                filter &= builder.Eq(o => o.Date, date);

            if (minTotal.HasValue)
                filter &= builder.Gte(o => o.Total, minTotal.Value);

            if (maxTotal.HasValue)
                filter &= builder.Lte(o => o.Total, maxTotal.Value);

            var results = await _collection
                .Find(filter)
                .SortBy(o => o.InvoiceId)
                .ToListAsync();

            return Ok(results);
        }

        // GET api/ocrsamples/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<OcrSample>> GetById(string id)
        {
            var sample = await _collection
                .Find(o => o.Id == id)
                .FirstOrDefaultAsync();

            if (sample is null)
                return NotFound(new { message = $"Không tìm thấy OCR sample với id: {id}" });

            return Ok(sample);
        }

        // GET api/ocrsamples/invoice/{invoiceId}
        // Tìm theo invoice_id (INV-100, INV-101, ...)
        [HttpGet("invoice/{invoiceId}")]
        public async Task<ActionResult<OcrSample>> GetByInvoiceId(string invoiceId)
        {
            var sample = await _collection
                .Find(o => o.InvoiceId == invoiceId)
                .FirstOrDefaultAsync();

            if (sample is null)
                return NotFound(new { message = $"Không tìm thấy hóa đơn: {invoiceId}" });

            return Ok(sample);
        }

        // GET api/ocrsamples/summary
        [HttpGet("summary")]
        public async Task<ActionResult<object>> GetSummary()
        {
            var all = await _collection.Find(_ => true).ToListAsync();

            if (all.Count == 0)
                return Ok(new { message = "Chưa có dữ liệu." });

            return Ok(new
            {
                totalInvoices = all.Count,
                minTotal      = all.Min(o => o.Total),
                maxTotal      = all.Max(o => o.Total),
                avgTotal      = (long)all.Average(o => o.Total),
                totalRevenue  = all.Sum(o => o.Total),
                stores        = all.Select(o => o.Store).Distinct().ToList(),
            });
        }

        // POST api/ocrsamples
        [HttpPost]
        public async Task<ActionResult<OcrSample>> Create([FromBody] OcrSample sample)
        {
            sample.Id = null;
            await _collection.InsertOneAsync(sample);
            return CreatedAtAction(nameof(GetById), new { id = sample.Id }, sample);
        }
    }
}
