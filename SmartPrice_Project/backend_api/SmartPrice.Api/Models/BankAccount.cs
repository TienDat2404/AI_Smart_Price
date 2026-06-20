using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    /// <summary>
    /// Tài khoản ngân hàng liên kết qua SePay.
    /// Lưu trong collection "BankAccounts".
    /// </summary>
    public class BankAccount
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        /// <summary>Liên kết với Users._id</summary>
        [BsonElement("UserId")]
        public string UserId { get; set; } = null!;

        /// <summary>Tên ngân hàng: "MBBank", "Techcombank", "VPBank"...</summary>
        [BsonElement("BankName")]
        public string BankName { get; set; } = null!;

        /// <summary>Số tài khoản (che bớt ở client: **** 4521)</summary>
        [BsonElement("AccountNumber")]
        public string AccountNumber { get; set; } = null!;

        /// <summary>Tên chủ tài khoản</summary>
        [BsonElement("AccountHolder")]
        public string AccountHolder { get; set; } = null!;

        /// <summary>SePay API Token do người dùng cung cấp</summary>
        [BsonElement("SePayToken")]
        public string SePayToken { get; set; } = null!;

        /// <summary>Số dư cuối cùng ghi nhận từ SePay webhook</summary>
        [BsonElement("Balance")]
        [BsonRepresentation(BsonType.Decimal128)]
        public decimal Balance { get; set; } = 0;

        /// <summary>Trạng thái: "active" | "inactive" | "error"</summary>
        [BsonElement("Status")]
        public string Status { get; set; } = "active";

        /// <summary>Thời điểm tạo liên kết</summary>
        [BsonElement("CreatedAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>Lần cuối nhận được webhook từ SePay</summary>
        [BsonElement("LastSyncAt")]
        public DateTime? LastSyncAt { get; set; }
    }

    // ── DTOs ──────────────────────────────────────────────────────────────────

    public record LinkBankRequest(
        string UserId,
        string BankName,
        string AccountNumber,
        string AccountHolder,
        string SePayToken
    );

    public record BankAccountDto(
        string   Id,
        string   UserId,
        string   BankName,
        string   AccountNumberMasked,   // **** 4521
        string   AccountHolder,
        decimal  Balance,
        string   Status,
        DateTime CreatedAt,
        DateTime? LastSyncAt
    );

    public record SetBalanceRequest(double Balance);
}
