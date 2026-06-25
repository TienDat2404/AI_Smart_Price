import 'auth_service.dart';

/// Cung cấp userId của user đang đăng nhập hiện tại.
///
/// Sử dụng:
///   final uid = await CurrentUser.id;   // async khi cần đọc từ disk lần đầu
///   final uid = CurrentUser.cachedId;   // sync sau khi đã load (không null-safe)
class CurrentUser {
  CurrentUser._();

  static String? _cachedId;
  static String? _cachedName;

  /// Load thông tin user từ SharedPreferences vào cache.
  /// Gọi một lần sau khi login thành công.
  static Future<void> load() async {
    _cachedId   = await AuthService.instance.getUserId();
    _cachedName = await AuthService.instance.getUserName();
  }

  /// Xóa cache khi logout.
  static void clear() {
    _cachedId   = null;
    _cachedName = null;
  }

  /// userId hiện tại — async, đọc từ SharedPreferences nếu chưa cache.
  static Future<String> get id async {
    if (_cachedId != null) return _cachedId!;
    _cachedId = await AuthService.instance.getUserId();
    return _cachedId ?? 'user_01'; // fallback an toàn cho dev/demo
  }

  /// userId đồng bộ — chỉ dùng sau khi đã gọi load() hoặc id (async).
  static String get cachedId => _cachedId ?? 'user_01';

  /// Tên hiển thị của user hiện tại.
  static Future<String> get name async {
    if (_cachedName != null) return _cachedName!;
    _cachedName = await AuthService.instance.getUserName();
    return _cachedName ?? 'Người dùng';
  }

  static String get cachedName => _cachedName ?? 'Người dùng';
}
