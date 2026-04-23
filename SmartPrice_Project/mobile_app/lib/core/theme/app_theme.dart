import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Light Theme ───────────────────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          primaryContainer: AppColors.neonCyan,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
          secondary: AppColors.secondaryGreen,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.black.withValues(alpha: 0.06),
          thickness: 1,
        ),
      );

  // ── Neon Dark Theme ───────────────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonBlue,
          primaryContainer: Color(0xFF003D52),
          secondary: AppColors.neonPurple,
          secondaryContainer: Color(0xFF2D1B4E),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          onPrimary: AppColors.darkBg,
          error: AppColors.neonRed,
          onError: AppColors.darkBg,
          outline: AppColors.darkBorder,
        ),
        scaffoldBackgroundColor: AppColors.darkBg,

        // Card — viền neon mờ, nền tối
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppColors.neonBlue.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),

        // Button — gradient neon
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonBlue,
            foregroundColor: AppColors.darkBg,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // AppBar — trong suốt, status bar sáng
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: AppColors.neonBlue),
        ),

        // Bottom nav — nền tối, icon neon
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.neonBlue,
          unselectedItemColor: AppColors.darkTextSecondary,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),

        // Input — nền tối, focus border neon
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurface2,
          hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.darkBorder,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.neonBlue,
              width: 1.5,
            ),
          ),
        ),

        // Text
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
          bodySmall: TextStyle(color: AppColors.darkTextSecondary),
          titleLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Icon
        iconTheme: const IconThemeData(color: AppColors.neonBlue),

        // Divider
        dividerTheme: DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),

        // Switch / Checkbox
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.neonBlue;
            }
            return AppColors.darkTextSecondary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.neonBlue.withValues(alpha: 0.3);
            }
            return AppColors.darkSurface2;
          }),
        ),
      );
}
