using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Mẫu hóa đơn OCR — tên field khớp với document MongoDB.
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

        /// <summary>Độ tin cậy OCR từ EasyOCR (0.0 – 1.0).</summary>
        [BsonElement("confidence")]
        public double Confidence { get; set; } = 0.0;

        /// <summary>OCR thành công nếu tìm được số tiền và confidence đủ cao.</summary>
        [BsonElement("is_success")]
        public bool IsSuccess { get; set; } = true;

        /// <summary>Status từ Python: "success" | "low_confidence" | "failed".</summary>
        [BsonElement("status")]
        public string Status { get; set; } = "success";

        /// <summary>Thời điểm quét.</summary>
        [BsonElement("scanned_at")]
        public DateTime ScannedAt { get; set; } = DateTime.UtcNow;
    }
}
