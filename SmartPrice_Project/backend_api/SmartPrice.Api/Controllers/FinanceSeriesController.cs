using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FinanceSeriesController : ControllerBase
    {
        private readonly IMongoCollection<FinanceSeries> _collection;

        public FinanceSeriesController(IMongoDatabase db)
        {
            _collection = db.GetCollection<FinanceSeries>("FinanceSeries");
        }

        // GET api/financeseries
        [HttpGet]
        public async Task<ActionResult<List<FinanceSeries>>> GetAll(
            [FromQuery] string? from,
            [FromQuery] string? to)
        {
            var builder = Builders<FinanceSeries>.Filter;
            var filter  = builder.Empty;

            // Lọc theo chuỗi ngày "YYYY-MM-DD" — so sánh lexicographic hoạt động đúng với ISO format
            if (!string.IsNullOrEmpty(from))
                filter &= builder.Gte(f => f.Date, from);

            if (!string.IsNullOrEmpty(to))
                filter &= builder.Lte(f => f.Date, to);

            var results = await _collection
                .Find(filter)
                .SortBy(f => f.Date)
                .ToListAsync();

            return Ok(results);
        }

        // GET api/financeseries/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<FinanceSeries>> GetById(string id)
        {
            var item = await _collection
                .Find(f => f.Id == id)
                .FirstOrDefaultAsync();

            if (item is null)
                return NotFound(new { message = $"Không tìm thấy finance series với id: {id}" });

            return Ok(item);
        }

        // GET api/financeseries/last7days
        // Trả về 7 ngày gần nhất — dùng cho biểu đồ Dashboard
        [HttpGet("last7days")]
        public async Task<ActionResult<List<FinanceSeries>>> GetLast7Days()
        {
            var cutoff = DateTime.UtcNow.AddDays(-7).ToString("yyyy-MM-dd");

            var results = await _collection
                .Find(f => string.Compare(f.Date, cutoff) >= 0)
                .SortBy(f => f.Date)
                .ToListAsync();

            return Ok(results);
        }

        // GET api/financeseries/summary
        // Thống kê tổng hợp toàn bộ time-series
        [HttpGet("summary")]
        public async Task<ActionResult<object>> GetSummary()
        {
            var all = await _collection.Find(_ => true).ToListAsync();

            if (all.Count == 0)
                return Ok(new { message = "Chưa có dữ liệu." });

            return Ok(new
            {
                totalRecords = all.Count,
                minAmount    = all.Min(f => f.Amount),
                maxAmount    = all.Max(f => f.Amount),
                avgAmount    = (long)all.Average(f => f.Amount),
                totalAmount  = all.Sum(f => f.Amount),
                dateFrom     = all.Min(f => f.Date),
                dateTo       = all.Max(f => f.Date),
            });
        }

        // POST api/financeseries
        [HttpPost]
        public async Task<ActionResult<FinanceSeries>> Create([FromBody] FinanceSeries item)
        {
            item.Id = null;
            await _collection.InsertOneAsync(item);
            return CreatedAtAction(nameof(GetById), new { id = item.Id }, item);
        }
    }
}
