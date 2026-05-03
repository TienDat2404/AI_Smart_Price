using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Bản ghi NLP training — tên field khớp với document MongoDB.
    ///
    /// DataSeeder dùng [BsonElement("nlp_id")], "raw_text", "intent", "entities"
    /// nên các field trong DB là snake_case.
    /// </summary>
    public class NlpSample
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("nlp_id")]
        public int NlpId { get; set; }

        [BsonElement("raw_text")]
        public string RawText { get; set; } = null!;

        [BsonElement("intent")]
        public string Intent { get; set; } = null!;

        [BsonElement("entities")]
        public NlpEntities Entities { get; set; } = null!;
    }

    public class NlpEntities
    {
        [BsonElement("item")]
        public string Item { get; set; } = null!;

        /// <summary>Giá tiền — lưu dạng Decimal128 trong MongoDB.</summary>
        [BsonElement("price")]
        [BsonRepresentation(BsonType.Decimal128)]
        public decimal Price { get; set; }

        [BsonElement("category")]
        public string Category { get; set; } = null!;
    }
}
