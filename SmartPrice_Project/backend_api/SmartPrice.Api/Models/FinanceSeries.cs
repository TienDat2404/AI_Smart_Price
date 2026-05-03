using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Điểm dữ liệu time-series tài chính — tên field khớp với document MongoDB.
    ///
    /// DataSeeder dùng [BsonElement("date")] và [BsonElement("amount")]
    /// nên các field trong DB là lowercase.
    /// </summary>
    public class FinanceSeries
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        /// <summary>Ngày dạng "YYYY-MM-DD" — lưu dạng string để dễ filter.</summary>
        [BsonElement("date")]
        public string Date { get; set; } = null!;

        [BsonElement("amount")]
        public long Amount { get; set; }
    }
}
