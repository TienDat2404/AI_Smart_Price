import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/mobile_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProviderScope.of(context);
    final isDark = theme.isDarkMode;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: MobileLayout(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Giao diện ─────────────────────────────────────────────────
            _SectionHeader(label: 'Giao diện'),

            // Dark Mode toggle — điểm nhấn chính
            _NeonDarkModeCard(isDark: isDark, onToggle: theme.toggleTheme),

            const SizedBox(height: 8),

            // ── Tài khoản ─────────────────────────────────────────────────
            _SectionHeader(label: 'Tài khoản'),

            _SettingsTile(
              icon: Icons.person_outline,
              label: 'Thông tin cá nhân',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              label: 'Đổi mật khẩu',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Thông báo',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
              ),
            ),

            const SizedBox(height: 8),

            // ── Ứng dụng ──────────────────────────────────────────────────
            _SectionHeader(label: 'Ứng dụng'),

            _SettingsTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: 'Tiếng Việt',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'Phiên bản',
              value: '1.0.0',
            ),

            const SizedBox(height: 8),

            // ── Đăng xuất ─────────────────────────────────────────────────
            _SectionHeader(label: 'Phiên làm việc'),

            _SettingsTile(
              icon: Icons.logout,
              label: 'Đăng xuất',
              labelColor: AppColors.neonRed,
              iconColor: AppColors.neonRed,
              onTap: () {
                // TODO: AuthService.logout() + navigate to LoginScreen
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Neon Dark Mode Card ───────────────────────────────────────────────────────

class _NeonDarkModeCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _NeonDarkModeCard({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    AppColors.darkSurface,
                    AppColors.darkSurface2,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.neonCyan.withValues(alpha: 0.05),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.neonBlue.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon với hiệu ứng glow khi dark
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neonBlue.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppColors.neonBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                color: isDark ? AppColors.neonBlue : AppColors.primary,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDark ? 'Neon Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark
                        ? 'Giao diện tối với hiệu ứng Neon'
                        : 'Giao diện sáng mặc định',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle switch với màu neon
            Switch(
              value: isDark,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.neonBlue,
              activeTrackColor: AppColors.neonBlue.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    this.labelColor,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (iconColor ?? cs.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? cs.primary,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor ??
                (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
        ),
        trailing: trailing ??
            (value != null
                ? Text(
                    value!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  )
                : onTap != null
                    ? Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        size: 20,
                      )
                    : null),
      ),
    );
  }
}
