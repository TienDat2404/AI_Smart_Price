using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    public class Transaction
    {
        [BsonId] // Đánh dấu đây là khóa chính của MongoDB
        [BsonRepresentation(BsonType.ObjectId)] // Tự động chuyển đổi từ chuỗi sang ObjectId của Mongo
        public string? Id { get; set; }

        public string ItemName { get; set; } = null!; // Tên món đồ/dịch vụ
        
        public decimal Amount { get; set; } // Số tiền
        
        public DateTime Date { get; set; } // Ngày giao dịch
        
        public string Category { get; set; } = null!; // Phân loại (Ăn uống, Di chuyển...)
    }
}