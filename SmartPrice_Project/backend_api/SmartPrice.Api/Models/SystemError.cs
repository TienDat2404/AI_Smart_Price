using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Ghi nhận lỗi hệ thống — dùng để tính "Active Incidents" thực tế.
    /// </summary>
    public class SystemError
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        /// <summary>Nguồn lỗi: "OCR", "API", "Auth", "DB", "AI"...</summary>
        [BsonElement("source")]
        public string Source { get; set; } = "Unknown";

        /// <summary>Mô tả lỗi ngắn gọn.</summary>
        [BsonElement("message")]
        public string Message { get; set; } = string.Empty;

        /// <summary>Mức độ: "error" | "warning" | "critical".</summary>
        [BsonElement("level")]
        public string Level { get; set; } = "error";

        /// <summary>Đã được xử lý chưa.</summary>
        [BsonElement("is_resolved")]
        public bool IsResolved { get; set; } = false;

        /// <summary>Thời điểm xảy ra lỗi.</summary>
        [BsonElement("occurred_at")]
        public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
    }
}
