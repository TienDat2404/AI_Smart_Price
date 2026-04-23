import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Light Mode ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF006876);
  static const Color neonCyan = Color(0xFF00BCD4);
  static const Color secondaryGreen = Color(0xFF006D37);

  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Colors.white;
  static const Color inputBackground = Color(0xFFECEEEF);

  static const Color textPrimary = Color(0xFF191C1D);
  static const Color textSecondary = Colors.grey;

  static const Color expense = Colors.red;
  static const Color income = Color(0xFF006D37);
  static const Color warning = Colors.orange;
  static const Color alert = Colors.red;

  // ── Neon Dark Mode ────────────────────────────────────────────────────────
  // Nền tối nhiều lớp — tạo chiều sâu
  static const Color darkBg = Color(0xFF0A0E1A);         // nền ngoài cùng
  static const Color darkSurface = Color(0xFF111827);    // card / panel
  static const Color darkSurface2 = Color(0xFF1A2235);   // input / elevated
  static const Color darkBorder = Color(0xFF1E2D45);     // viền nhẹ

  // Neon accents
  static const Color neonBlue = Color(0xFF00D4FF);       // primary neon
  static const Color neonPurple = Color(0xFFBB86FC);     // secondary neon
  static const Color neonGreen = Color(0xFF00FF9D);      // income / success
  static const Color neonRed = Color(0xFFFF4D6A);        // expense / alert
  static const Color neonOrange = Color(0xFFFF9500);     // warning

  // Text trên nền tối
  static const Color darkTextPrimary = Color(0xFFE8F0FE);
  static const Color darkTextSecondary = Color(0xFF8899AA);
}
