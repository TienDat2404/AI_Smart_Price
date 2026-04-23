import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý trạng thái Dark/Light mode toàn app.
/// Lưu lựa chọn vào SharedPreferences để nhớ sau khi tắt app.
///
/// Cách dùng:
/// ```dart
/// // Đọc theme hiện tại
/// final isDark = ThemeProvider.of(context).isDarkMode;
///
/// // Toggle
/// ThemeProvider.of(context).toggleTheme();
/// ```
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'is_dark_mode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Khởi tạo từ SharedPreferences — gọi trước runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Toggle Dark ↔ Light và lưu vào SharedPreferences.
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }

  /// Set trực tiếp (dùng trong Settings).
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }
}

/// InheritedWidget để truy cập ThemeProvider từ bất kỳ đâu trong widget tree.
class ThemeProviderScope extends InheritedNotifier<ThemeProvider> {
  const ThemeProviderScope({
    super.key,
    required ThemeProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static ThemeProvider of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeProviderScope>();
    assert(scope != null, 'ThemeProviderScope không tìm thấy trong widget tree');
    return scope!.notifier!;
  }
}
