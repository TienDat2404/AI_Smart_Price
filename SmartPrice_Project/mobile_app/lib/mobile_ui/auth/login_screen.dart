import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onLogin() async {
    // 1. Validate form trước
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 2. Gọi API đăng nhập
      final response = await ApiService.instance.login(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );

      // 3. Lưu token và thông tin user vào SharedPreferences
      await Future.wait([
        AuthService.instance.saveToken(response.token),
        AuthService.instance.saveUserInfo(
          userId: response.userId,
          name: response.name,
          email: response.email,
          isAdmin: response.isAdmin,
        ),
      ]);

      // 4. Điều hướng — dùng pushReplacement để không thể back về Login
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on ApiException catch (e) {
      // Xử lý lỗi từ server có HTTP status code
      setState(() {
        _errorMessage = switch (e.statusCode) {
          401 => 'Email hoặc mật khẩu không đúng.',
          403 => 'Tài khoản của bạn đã bị khóa.',
          404 => 'Tài khoản không tồn tại.',
          429 => 'Quá nhiều lần thử. Vui lòng đợi vài phút.',
          >= 500 => 'Lỗi máy chủ. Vui lòng thử lại sau.',
          _ => e.message,
        };
      });
    } catch (e) {
      // Lỗi mạng, timeout, v.v.
      setState(() {
        _errorMessage = 'Không thể kết nối. Kiểm tra lại kết nối mạng.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _goToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MobileLayout.scrollable(
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                const AuthHeader(
                  title: 'Chào mừng trở lại!',
                  subtitle: 'Đăng nhập để tiếp tục quản lý tài chính.',
                ),

                const SizedBox(height: 36),

                // ── Email ────────────────────────────────────────────────
                CustomTextField(
                  label: 'Email',
                  hint: 'example@email.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  enabled: !_isLoading,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Password ─────────────────────────────────────────────
                CustomTextField(
                  label: 'Mật khẩu',
                  hint: '••••••••',
                  controller: _passwordCtrl,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _onLogin(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ── Quên mật khẩu ────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _goToForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Error message ────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),

                // ── Nút Đăng nhập ────────────────────────────────────────
                AuthButton(
                  label: 'Đăng nhập',
                  onPressed: _isLoading ? null : _onLogin,
                  isLoading: _isLoading,
                  icon: Icons.login_rounded,
                ),

                const SizedBox(height: 24),

                // ── Divider ──────────────────────────────────────────────
                const AuthDivider(),

                const SizedBox(height: 20),

                // ── Social Auth ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: SocialAuthButton(
                        label: 'Face ID',
                        icon: const Icon(
                          Icons.face_retouching_natural,
                          color: AppColors.primary,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                // TODO: Implement biometric auth
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialAuthButton(
                        label: 'Google',
                        icon: _GoogleIcon(),
                        onPressed: _isLoading
                            ? null
                            : () {
                                // TODO: Implement Google Sign-In
                              },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Chuyển sang Register ─────────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _goToRegister,
                        child: const Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.alert.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alert.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.alert),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.alert),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
        fontFamily: 'Inter',
      ),
    );
  }
}
