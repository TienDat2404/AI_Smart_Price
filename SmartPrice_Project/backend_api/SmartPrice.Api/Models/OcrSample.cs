using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Mẫu hóa đơn OCR — tên field khớp với document MongoDB.
    ///
    /// DataSeeder dùng [BsonElement("invoice_id")], "store", "total", "date"
    /// nên các field trong DB là snake_case / lowercase.
    /// </summary>
    public class OcrSample
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("invoice_id")]
        public string InvoiceId { get; set; } = null!;

        [BsonElement("store")]
        public string Store { get; set; } = null!;

        [BsonElement("total")]
        public long Total { get; set; }

        /// <summary>Ngày dạng "YYYY-MM-DD" — lưu dạng string.</summary>
        [BsonElement("date")]
        public string Date { get; set; } = null!;
    }
}
