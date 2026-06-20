using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Mục tiêu tiết kiệm — lưu trong collection "SavingsGoals".
    /// </summary>
    public class SavingsGoal
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("UserId")]
        public string UserId { get; set; } = null!;

        [BsonElement("Title")]
        public string Title { get; set; } = null!;

        [BsonElement("TargetAmount")]
        [BsonRepresentation(BsonType.Decimal128)]
        public decimal TargetAmount { get; set; }

        [BsonElement("CurrentAmount")]
        [BsonRepresentation(BsonType.Decimal128)]
        public decimal CurrentAmount { get; set; } = 0;

        /// <summary>Deadline dạng ISO string "yyyy-MM-dd"</summary>
        [BsonElement("Deadline")]
        public DateTime Deadline { get; set; }

        /// <summary>Tên icon danh mục (dùng để map icon phía Flutter)</summary>
        [BsonElement("CategoryIcon")]
        public string CategoryIcon { get; set; } = "star";

        /// <summary>Màu hex "#1565C0"</summary>
        [BsonElement("Color")]
        public string Color { get; set; } = "#1565C0";

        [BsonElement("AiInsight")]
        public string AiInsight { get; set; } = "";

        [BsonElement("IsCompleted")]
        public bool IsCompleted { get; set; } = false;

        [BsonElement("CreatedAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    // ── DTOs ──────────────────────────────────────────────────────────────────

    public record CreateGoalRequest(
        string  UserId,
        string  Title,
        double  TargetAmount,
        string  Deadline,      // "yyyy-MM-dd"
        string  CategoryIcon,
        string  Color,
        string? AiInsight
    );

    public record AddToGoalRequest(double Amount);

    public record GoalDto(
        string  Id,
        string  UserId,
        string  Title,
        double  TargetAmount,
        double  CurrentAmount,
        string  Deadline,
        string  CategoryIcon,
        string  Color,
        string  AiInsight,
        bool    IsCompleted,
        double  Progress,
        int     DaysLeft
    );
}
