using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Giao dịch tài chính — tên field khớp chính xác với document trong MongoDB.
    ///
    /// Lưu ý: DataSeeder insert bằng object C# không có [BsonElement],
    /// nên MongoDB lưu tên field theo tên property (PascalCase).
    /// Các [BsonElement] dưới đây map đúng với tên đó.
    /// </summary>
    public class Transaction
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("UserId")]
        public string UserId { get; set; } = "user_01";

        [BsonElement("ItemName")]
        public string ItemName { get; set; } = null!;

        /// <summary>Số tiền — lưu dạng Decimal128 trong MongoDB.</summary>
        [BsonElement("Amount")]
        [BsonRepresentation(BsonType.Decimal128)]
        public decimal Amount { get; set; }

        [BsonElement("Date")]
        public DateTime Date { get; set; }

        [BsonElement("Category")]
        public string Category { get; set; } = null!;

        [BsonElement("IsExpense")]
        public bool IsExpense { get; set; } = true;

        [BsonElement("Note")]
        public string Note { get; set; } = string.Empty;
    }
}
