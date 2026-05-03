import 'package:flutter/material.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'mobile_ui/analytics/analytics_screen.dart';
import 'mobile_ui/auth/login_screen.dart';
import 'mobile_ui/dashboard/dashboard_screen.dart';

// ThemeProvider singleton
final _themeProvider = ThemeProvider();

// NavigatorKey để điều hướng từ notification tap
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _themeProvider.init();

  // Khởi tạo NotificationService
  await NotificationService.instance.init();

  // Khi user nhấn notification → mở AnalyticsScreen
  NotificationService.instance.onNotificationTap = (payload) {
    if (payload == 'analytics') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
      );
    }
  };

  runApp(const SmartPriceApp());
}

class SmartPriceApp extends StatelessWidget {
  const SmartPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder rebuild MaterialApp khi theme thay đổi
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        return ThemeProviderScope(
          provider: _themeProvider,
          child: MaterialApp(
            title: 'SmartPrice AI',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _themeProvider.themeMode,
            home: const _SplashGate(),
          ),
        );
      },
    );
  }
}

// ── Splash Gate ───────────────────────────────────────────────────────────────

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeProvider.isDarkMode;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBg : AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.neonCyan],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppColors.neonBlue.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SmartPrice AI',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.neonBlue : AppColors.primary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: isDark ? AppColors.neonBlue : AppColors.neonCyan,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
