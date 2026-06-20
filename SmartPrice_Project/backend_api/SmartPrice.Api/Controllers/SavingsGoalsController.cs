using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Controllers
{
    /// <summary>
    /// Quản lý mục tiêu tiết kiệm.
    ///
    /// GET    /api/savings-goals?userId=...     — danh sách mục tiêu
    /// POST   /api/savings-goals                — tạo mục tiêu mới
    /// PATCH  /api/savings-goals/{id}/add       — thêm tiền vào quỹ
    /// DELETE /api/savings-goals/{id}           — xóa mục tiêu
    /// </summary>
    [ApiController]
    [Route("api/savings-goals")]
    public class SavingsGoalsController : ControllerBase
    {
        private readonly IMongoCollection<SavingsGoal> _goals;
        private readonly ILogger<SavingsGoalsController> _logger;

        public SavingsGoalsController(IMongoDatabase db, ILogger<SavingsGoalsController> logger)
        {
            _goals  = db.GetCollection<SavingsGoal>("SavingsGoals");
            _logger = logger;
        }

        // ── GET /api/savings-goals?userId=... ────────────────────────────────

        [HttpGet]
        public async Task<IActionResult> GetByUser([FromQuery] string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return BadRequest(new { message = "userId is required." });

            var goals = await _goals
                .Find(g => g.UserId == userId)
                .SortByDescending(g => g.CreatedAt)
                .ToListAsync();

            return Ok(goals.Select(ToDto).ToList());
        }

        // ── POST /api/savings-goals ──────────────────────────────────────────

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateGoalRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Title))
                return BadRequest(new { message = "Tên mục tiêu không được trống." });

            if (req.TargetAmount <= 0)
                return BadRequest(new { message = "Số tiền mục tiêu phải lớn hơn 0." });

            if (!DateTime.TryParse(req.Deadline, out var deadline))
                return BadRequest(new { message = "Ngày không hợp lệ." });

            // Tính AI insight tự động
            var months    = deadline.Subtract(DateTime.Now).TotalDays / 30;
            var monthly   = months > 0 ? req.TargetAmount / months : req.TargetAmount;
            var aiInsight = req.AiInsight ?? $"Cần tiết kiệm khoảng {monthly:N0}đ/tháng để đạt mục tiêu đúng hạn.";

            var goal = new SavingsGoal
            {
                UserId       = req.UserId,
                Title        = req.Title,
                TargetAmount = (decimal)req.TargetAmount,
                CurrentAmount= 0,
                Deadline     = deadline,
                CategoryIcon = req.CategoryIcon,
                Color        = req.Color,
                AiInsight    = aiInsight,
                IsCompleted  = false,
                CreatedAt    = DateTime.UtcNow,
            };

            await _goals.InsertOneAsync(goal);
            _logger.LogInformation("Goal created: {Title} for {UserId}", goal.Title, goal.UserId);
            return Ok(ToDto(goal));
        }

        // ── PATCH /api/savings-goals/{id}/add ───────────────────────────────

        [HttpPatch("{id}/add")]
        public async Task<IActionResult> AddAmount(string id, [FromBody] AddToGoalRequest req)
        {
            if (req.Amount <= 0)
                return BadRequest(new { message = "Số tiền phải lớn hơn 0." });

            var goal = await _goals.Find(g => g.Id == id).FirstOrDefaultAsync();
            if (goal == null) return NotFound(new { message = "Không tìm thấy mục tiêu." });

            var newAmount    = goal.CurrentAmount + (decimal)req.Amount;
            var isCompleted  = newAmount >= goal.TargetAmount;

            await _goals.UpdateOneAsync(
                g => g.Id == id,
                Builders<SavingsGoal>.Update
                    .Set(g => g.CurrentAmount, newAmount)
                    .Set(g => g.IsCompleted,   isCompleted)
            );

            goal.CurrentAmount = newAmount;
            goal.IsCompleted   = isCompleted;

            return Ok(ToDto(goal));
        }

        // ── DELETE /api/savings-goals/{id} ──────────────────────────────────

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            var result = await _goals.DeleteOneAsync(g => g.Id == id);
            if (result.DeletedCount == 0)
                return NotFound(new { message = "Không tìm thấy mục tiêu." });

            return Ok(new { message = "Đã xóa mục tiêu." });
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        private static GoalDto ToDto(SavingsGoal g)
        {
            var progress = g.TargetAmount > 0
                ? Math.Clamp((double)g.CurrentAmount / (double)g.TargetAmount, 0.0, 1.0)
                : 0.0;
            var daysLeft = Math.Max(0, (g.Deadline - DateTime.Now).Days);

            return new GoalDto(
                Id:            g.Id!,
                UserId:        g.UserId,
                Title:         g.Title,
                TargetAmount:  (double)g.TargetAmount,
                CurrentAmount: (double)g.CurrentAmount,
                Deadline:      g.Deadline.ToString("yyyy-MM-dd"),
                CategoryIcon:  g.CategoryIcon,
                Color:         g.Color,
                AiInsight:     g.AiInsight,
                IsCompleted:   g.IsCompleted,
                Progress:      progress,
                DaysLeft:      daysLeft
            );
        }
    }
}
