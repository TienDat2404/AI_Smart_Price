using Microsoft.AspNetCore.Mvc;
using SmartPrice.Api.Models;
using SmartPrice.Api.Services;

namespace SmartPrice.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UsersController : ControllerBase
    {
        private readonly UserService _userService;

        public UsersController(UserService userService)
        {
            _userService = userService;
        }

        // ── POST /api/users/register ──────────────────────────────────────────

        /// <summary>Đăng ký tài khoản mới.</summary>
        [HttpPost("register")]
        [ProducesResponseType(typeof(UserDto), 201)]
        [ProducesResponseType(typeof(object), 409)]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Password) ||
                string.IsNullOrWhiteSpace(request.FullName))
            {
                return BadRequest(new { message = "FullName, Email và Password không được để trống." });
            }

            if (request.Password.Length < 6)
                return BadRequest(new { message = "Password phải có ít nhất 6 ký tự." });

            try
            {
                var user = await _userService.RegisterAsync(request);
                return CreatedAtAction(nameof(GetById),
                    new { id = user.Id },
                    UserService.ToDto(user));
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(new { message = ex.Message });
            }
        }

        // ── POST /api/users/login ─────────────────────────────────────────────

        /// <summary>Đăng nhập — trả về thông tin user (token giả lập).</summary>
        [HttpPost("login")]
        [ProducesResponseType(typeof(LoginResponse), 200)]
        [ProducesResponseType(typeof(object), 401)]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var user = await _userService.AuthenticateAsync(request.Email, request.Password);
            if (user is null)
                return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });

            // TODO: Thay token giả bằng JWT thực khi cần xác thực đầy đủ
            var fakeToken = Convert.ToBase64String(
                System.Text.Encoding.UTF8.GetBytes($"{user.Id}:{user.Email}:{DateTime.UtcNow.Ticks}")
            );

            return Ok(new LoginResponse(
                Token:   fakeToken,
                UserId:  user.Id!,
                Name:    user.FullName,
                Email:   user.Email,
                IsAdmin: user.Role == UserRole.Admin
            ));
        }

        // ── GET /api/users ────────────────────────────────────────────────────

        /// <summary>Lấy danh sách tất cả user (Admin only).</summary>
        [HttpGet]
        [ProducesResponseType(typeof(List<UserDto>), 200)]
        public async Task<IActionResult> GetAll()
        {
            var users = await _userService.GetAllAsync();
            return Ok(users.Select(UserService.ToDto));
        }

        // ── GET /api/users/{id} ───────────────────────────────────────────────

        /// <summary>Lấy thông tin một user theo ID.</summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(UserDto), 200)]
        [ProducesResponseType(404)]
        public async Task<IActionResult> GetById(string id)
        {
            var user = await _userService.GetByIdAsync(id);
            if (user is null)
                return NotFound(new { message = $"Không tìm thấy user với id: {id}" });

            return Ok(UserService.ToDto(user));
        }

        // ── PATCH /api/users/{id} ─────────────────────────────────────────────

        /// <summary>Khóa / mở khóa tài khoản user.</summary>
        [HttpPatch("{id}")]
        [ProducesResponseType(204)]
        [ProducesResponseType(404)]
        public async Task<IActionResult> SetActive(string id, [FromBody] SetActiveRequest request)
        {
            var updated = await _userService.SetActiveAsync(id, request.IsActive);
            if (!updated)
                return NotFound(new { message = $"Không tìm thấy user với id: {id}" });

            return NoContent();
        }
    }

    public record SetActiveRequest(bool IsActive);
}
