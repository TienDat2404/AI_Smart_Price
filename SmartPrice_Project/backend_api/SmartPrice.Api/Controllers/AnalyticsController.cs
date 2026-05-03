using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AnalyticsController : ControllerBase
    {
        private readonly IMongoCollection<Transaction> _transactions;

        public AnalyticsController(IMongoDatabase db)
        {
            _transactions = db.GetCollection<Transaction>("Transactions");
        }

        // GET /api/analytics/category-summary?userId=user_01
        [HttpGet("category-summary")]
        public async Task<IActionResult> GetCategorySummary([FromQuery] string? userId)
        {
            var filter = Builders<Transaction>.Filter.Eq(t => t.IsExpense, true);
            if (!string.IsNullOrEmpty(userId))
                filter &= Builders<Transaction>.Filter.Eq(t => t.UserId, userId);

            var all = await _transactions.Find(filter).ToListAsync();

            var grouped = all
                .GroupBy(t => t.Category)
                .Select(g => new
                {
                    category = g.Key,
                    total    = g.Sum(t => (double)t.Amount),
                    count    = g.Count(),
                })
                .OrderByDescending(x => x.total)
                .ToList();

            var grandTotal = grouped.Sum(x => x.total);

            var result = grouped.Select(x => new
            {
                x.category,
                x.total,
                x.count,
                percentage = grandTotal > 0 ? Math.Round(x.total / grandTotal * 100, 1) : 0,
            });

            return Ok(new
            {
                userId     = userId ?? "all",
                grandTotal,
                categories = result,
            });
        }

        // GET /api/analytics/monthly-trend?userId=user_01&months=6
        [HttpGet("monthly-trend")]
        public async Task<IActionResult> GetMonthlyTrend(
            [FromQuery] string? userId,
            [FromQuery] int months = 6)
        {
            var from = DateTime.UtcNow.AddMonths(-months);
            var filter = Builders<Transaction>.Filter.Gte(t => t.Date, from)
                       & Builders<Transaction>.Filter.Eq(t => t.IsExpense, true);

            if (!string.IsNullOrEmpty(userId))
                filter &= Builders<Transaction>.Filter.Eq(t => t.UserId, userId);

            var all = await _transactions.Find(filter).ToListAsync();

            var grouped = all
                .GroupBy(t => new { t.Date.Year, t.Date.Month })
                .Select(g => new
                {
                    year  = g.Key.Year,
                    month = g.Key.Month,
                    total = g.Sum(t => (double)t.Amount),
                    label = $"{g.Key.Month:D2}/{g.Key.Year}",
                })
                .OrderBy(x => x.year).ThenBy(x => x.month)
                .ToList();

            return Ok(grouped);
        }

        // GET /api/analytics/ai-advice?userId=user_01
        [HttpGet("ai-advice")]
        public async Task<IActionResult> GetAiAdvice([FromQuery] string? userId)
        {
            var now       = DateTime.UtcNow;
            var thisMonth = new DateTime(now.Year, now.Month, 1);
            var lastMonth = thisMonth.AddMonths(-1);

            var baseFilter = Builders<Transaction>.Filter.Eq(t => t.IsExpense, true);
            if (!string.IsNullOrEmpty(userId))
                baseFilter &= Builders<Transaction>.Filter.Eq(t => t.UserId, userId);

            // Tháng này
            var thisFilter = baseFilter
                & Builders<Transaction>.Filter.Gte(t => t.Date, thisMonth)
                & Builders<Transaction>.Filter.Lt(t => t.Date, thisMonth.AddMonths(1));

            // Tháng trước
            var lastFilter = baseFilter
                & Builders<Transaction>.Filter.Gte(t => t.Date, lastMonth)
                & Builders<Transaction>.Filter.Lt(t => t.Date, thisMonth);

            var thisMonthTxs = await _transactions.Find(thisFilter).ToListAsync();
            var lastMonthTxs = await _transactions.Find(lastFilter).ToListAsync();

            var thisTotal = thisMonthTxs.Sum(t => (double)t.Amount);
            var lastTotal = lastMonthTxs.Sum(t => (double)t.Amount);

            // Hạng mục cao nhất tháng này
            var topCategory = thisMonthTxs
                .GroupBy(t => t.Category)
                .OrderByDescending(g => g.Sum(t => (double)t.Amount))
                .FirstOrDefault()?.Key ?? "chi tieu";

            string advice;
            string adviceType; // "warning" | "tip" | "default"

            if (lastTotal > 0 && thisTotal > lastTotal * 1.2)
            {
                // Chi tiêu tăng > 20%
                var pct = Math.Round((thisTotal - lastTotal) / lastTotal * 100, 0);
                advice     = $"Chi tieu cua ban dang tang {pct}% so voi thang truoc. Hay kiem tra lai muc '{topCategory}' de tiet kiem hon nhe!";
                adviceType = "warning";
            }
            else if (topCategory.Contains("An uong") || topCategory.Contains("an uong"))
            {
                advice     = "Ban dang chi kha nhieu cho an uong. Thu nau an tai nha de tiet kiem them nhe!";
                adviceType = "tip";
            }
            else if (thisTotal == 0)
            {
                advice     = "Chua co du lieu chi tieu thang nay. Hay bat dau ghi chep de AI co the tu van cho ban!";
                adviceType = "default";
            }
            else
            {
                // Fallback: lời khuyên dựa trên hạng mục cao nhất
                advice     = $"Hang muc '{topCategory}' dang chiem ty trong cao nhat trong thang nay. Hay theo doi de quan ly tot hon!";
                adviceType = "default";
            }

            return Ok(new
            {
                advice,
                adviceType,
                topCategory,
                thisMonthTotal = thisTotal,
                lastMonthTotal = lastTotal,
                changePercent  = lastTotal > 0 ? Math.Round((thisTotal - lastTotal) / lastTotal * 100, 1) : 0,
            });
        }
    }
}
