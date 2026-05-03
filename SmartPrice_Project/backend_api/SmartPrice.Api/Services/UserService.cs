using MongoDB.Driver;
using SmartPrice.Api.Models;

namespace SmartPrice.Api.Services
{
    /// <summary>
    /// CRUD người dùng + xác thực — dùng BCrypt để hash/verify password.
    /// </summary>
    public class UserService
    {
        private readonly IMongoCollection<User> _users;

        public UserService(IMongoDatabase db)
        {
            _users = db.GetCollection<User>("Users");

            // Index unique trên Email để tránh trùng lặp
            var indexModel = new CreateIndexModel<User>(
                Builders<User>.IndexKeys.Ascending(u => u.Email),
                new CreateIndexOptions { Unique = true }
            );
            _users.Indexes.CreateOne(indexModel);
        }

        // ── Queries ───────────────────────────────────────────────────────────

        public async Task<List<User>> GetAllAsync() =>
            await _users.Find(_ => true).SortBy(u => u.CreatedAt).ToListAsync();

        public async Task<User?> GetByIdAsync(string id) =>
            await _users.Find(u => u.Id == id).FirstOrDefaultAsync();

        public async Task<User?> GetByEmailAsync(string email) =>
            await _users.Find(u => u.Email == email.ToLower()).FirstOrDefaultAsync();

        // ── Register ──────────────────────────────────────────────────────────

        /// <summary>
        /// Tạo tài khoản mới. Ném <see cref="InvalidOperationException"/> nếu email đã tồn tại.
        /// </summary>
        public async Task<User> RegisterAsync(RegisterRequest request)
        {
            var existing = await GetByEmailAsync(request.Email);
            if (existing is not null)
                throw new InvalidOperationException("Email đã được sử dụng.");

            var user = new User
            {
                Email        = request.Email.Trim().ToLower(),
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                FullName     = request.FullName.Trim(),
                Role         = UserRole.User,
                IsActive     = true,
                CreatedAt    = DateTime.UtcNow,
            };

            await _users.InsertOneAsync(user);
            return user;
        }

        // ── Login ─────────────────────────────────────────────────────────────

        /// <summary>
        /// Xác thực email + password. Trả về User nếu hợp lệ, null nếu sai.
        /// </summary>
        public async Task<User?> AuthenticateAsync(string email, string password)
        {
            var user = await GetByEmailAsync(email);
            if (user is null || !user.IsActive) return null;

            return BCrypt.Net.BCrypt.Verify(password, user.PasswordHash) ? user : null;
        }

        // ── Update ────────────────────────────────────────────────────────────

        public async Task<bool> SetActiveAsync(string id, bool isActive)
        {
            var update = Builders<User>.Update.Set(u => u.IsActive, isActive);
            var result = await _users.UpdateOneAsync(u => u.Id == id, update);
            return result.ModifiedCount > 0;
        }

        // ── Seed helper ───────────────────────────────────────────────────────

        /// <summary>Tạo admin mặc định nếu chưa tồn tại.</summary>
        public async Task EnsureAdminAsync(string email, string password, string fullName)
        {
            var existing = await GetByEmailAsync(email);
            if (existing is not null) return;

            var admin = new User
            {
                Email        = email.ToLower(),
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
                FullName     = fullName,
                Role         = UserRole.Admin,
                IsActive     = true,
                CreatedAt    = DateTime.UtcNow,
            };
            await _users.InsertOneAsync(admin);
            Console.WriteLine($"[UserService] Admin mặc định đã được tạo: {email}");
        }

        // ── Mapper ────────────────────────────────────────────────────────────

        public static UserDto ToDto(User u) => new(
            u.Id!,
            u.FullName,
            u.Email,
            u.Role.ToString(),
            u.IsActive,
            u.CreatedAt
        );
    }
}
