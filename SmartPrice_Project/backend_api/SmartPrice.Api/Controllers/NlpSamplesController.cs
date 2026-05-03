using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NlpSamplesController : ControllerBase
    {
        private readonly IMongoCollection<NlpSample> _collection;

        public NlpSamplesController(IMongoDatabase db)
        {
            _collection = db.GetCollection<NlpSample>("NlpSamples");
        }

        // GET api/nlpsamples
        [HttpGet]
        public async Task<ActionResult<List<NlpSample>>> GetAll(
            [FromQuery] string? intent,
            [FromQuery] string? category)
        {
            var builder = Builders<NlpSample>.Filter;
            var filter  = builder.Empty;

            if (!string.IsNullOrEmpty(intent))
                filter &= builder.Eq(n => n.Intent, intent);

            if (!string.IsNullOrEmpty(category))
                filter &= builder.Eq(n => n.Entities.Category, category);

            var results = await _collection
                .Find(filter)
                .SortBy(n => n.NlpId)
                .ToListAsync();

            return Ok(results);
        }

        // GET api/nlpsamples/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<NlpSample>> GetById(string id)
        {
            var sample = await _collection
                .Find(n => n.Id == id)
                .FirstOrDefaultAsync();

            if (sample is null)
                return NotFound(new { message = $"Không tìm thấy NLP sample với id: {id}" });

            return Ok(sample);
        }

        // GET api/nlpsamples/categories
        // Trả về danh sách các category duy nhất — hữu ích cho AI training
        [HttpGet("categories")]
        public async Task<ActionResult<List<string>>> GetCategories()
        {
            var all = await _collection.Find(_ => true).ToListAsync();
            var categories = all
                .Select(n => n.Entities.Category)
                .Distinct()
                .OrderBy(c => c)
                .ToList();

            return Ok(categories);
        }

        // POST api/nlpsamples
        [HttpPost]
        public async Task<ActionResult<NlpSample>> Create([FromBody] NlpSample sample)
        {
            sample.Id = null;
            await _collection.InsertOneAsync(sample);
            return CreatedAtAction(nameof(GetById), new { id = sample.Id }, sample);
        }
    }
}
