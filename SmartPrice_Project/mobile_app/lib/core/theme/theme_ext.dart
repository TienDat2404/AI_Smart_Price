import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension tiện lợi để lấy màu theo theme hiện tại (light/dark).
/// Dùng: context.colors.bg, context.colors.card, v.v.
extension ThemeContextExt on BuildContext {
  _AppColors get colors => _AppColors(Theme.of(this).brightness == Brightness.dark);
}

class _AppColors {
  final bool isDark;
  const _AppColors(this.isDark);

  // Backgrounds
  Color get bg     => isDark ? AppColors.darkBg      : const Color(0xFFF5F7FA);
  Color get card   => isDark ? AppColors.darkSurface  : Colors.white;
  Color get card2  => isDark ? AppColors.darkSurface2 : const Color(0xFFF0F4F8);
  Color get border => isDark ? AppColors.darkBorder   : Colors.black.withValues(alpha: 0.06);

  // Text
  Color get textPrimary   => isDark ? AppColors.darkTextPrimary   : const Color(0xFF1A2340);
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : const Color(0xFF8A94A6);

  // Brand
  Color get teal      => const Color(0xFF00897B);
  Color get tealDark  => const Color(0xFF00695C);
  Color get tealLight => isDark ? const Color(0xFF00897B).withValues(alpha: 0.15) : const Color(0xFFE0F2F1);
  Color get cyan      => const Color(0xFF00BCD4);

  // Status
  Color get red    => isDark ? AppColors.neonRed    : const Color(0xFFE53935);
  Color get green  => isDark ? AppColors.neonGreen  : const Color(0xFF43A047);
  Color get orange => isDark ? AppColors.neonOrange : const Color(0xFFFB8C00);

  // Shadow
  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))];
}
