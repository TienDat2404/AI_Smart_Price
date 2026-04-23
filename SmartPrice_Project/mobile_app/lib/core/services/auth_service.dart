import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý token JWT và thông tin session người dùng.
///
/// Tất cả logic đọc/ghi SharedPreferences được tập trung tại đây
/// để các service khác (ApiService, UI) không cần biết về storage.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyIsAdmin = 'is_admin';

  // ── In-memory cache (tránh đọc disk liên tục) ─────────────────────────────
  String? _cachedToken;

  // ── Token ─────────────────────────────────────────────────────────────────

  /// Lưu JWT token vào SharedPreferences và cache in-memory.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  /// Lấy token — ưu tiên cache, fallback về disk.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_keyToken);
    return _cachedToken;
  }

  /// Kiểm tra user đã đăng nhập chưa (có token hợp lệ).
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── User info ─────────────────────────────────────────────────────────────

  /// Lưu thông tin user sau khi đăng nhập thành công.
  Future<void> saveUserInfo({
    required String userId,
    required String name,
    required String email,
    required bool isAdmin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyUserName, name),
      prefs.setString(_keyUserEmail, email),
      prefs.setBool(_keyIsAdmin, isAdmin),
    ]);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<bool> getIsAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsAdmin) ?? false;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  /// Xóa toàn bộ session — gọi khi đăng xuất.
  Future<void> logout() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyToken),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserName),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyIsAdmin),
    ]);
  }
}
