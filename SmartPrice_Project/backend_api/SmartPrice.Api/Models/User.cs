using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace SmartPrice.Api.Models
{
    public enum UserRole { User, Admin }

    /// <summary>
    /// Tài khoản người dùng — lưu trong collection "Users".
    /// Password được hash bằng BCrypt trước khi lưu.
    /// </summary>
    public class User
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("Email")]
        public string Email { get; set; } = null!;

        /// <summary>BCrypt hash của mật khẩu — không bao giờ trả về client.</summary>
        [BsonElement("PasswordHash")]
        public string PasswordHash { get; set; } = null!;

        [BsonElement("FullName")]
        public string FullName { get; set; } = null!;

        [BsonElement("Role")]
        public UserRole Role { get; set; } = UserRole.User;

        [BsonElement("IsActive")]
        public bool IsActive { get; set; } = true;

        [BsonElement("CreatedAt")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    // ── Request / Response DTOs ───────────────────────────────────────────────

    public record RegisterRequest(string FullName, string Email, string Password);

    public record LoginRequest(string Email, string Password);

    public record LoginResponse(
        string Token,
        string UserId,
        string Name,
        string Email,
        bool IsAdmin
    );

    /// <summary>Thông tin user trả về client — không có PasswordHash.</summary>
    public record UserDto(
        string Id,
        string FullName,
        string Email,
        string Role,
        bool IsActive,
        DateTime CreatedAt
    );
}
