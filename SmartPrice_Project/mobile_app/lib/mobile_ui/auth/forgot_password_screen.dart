import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';
import 'auth_widgets.dart';

/// Màn hình quên mật khẩu — 2 bước:
/// Bước 1: Nhập email → gửi OTP
/// Bước 2: Xác nhận thành công
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onSendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Thay bằng ApiService.sendPasswordReset() khi backend sẵn sàng
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _emailSent = true);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Không tìm thấy tài khoản với email này.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MobileLayout(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _emailSent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  // ── Bước 1: Form nhập email ───────────────────────────────────────────────

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            padding: EdgeInsets.zero,
            onPressed: _goBack,
          ),

          const SizedBox(height: 24),

          // Icon minh họa
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.neonCyan.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Header
          const Center(
            child: Column(
              children: [
                Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Nhập email đã đăng ký. Chúng tôi sẽ gửi\nhướng dẫn đặt lại mật khẩu cho bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Email field
          CustomTextField(
            label: 'Email đã đăng ký',
            hint: 'example@email.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.email_outlined,
            onSubmitted: (_) => _onSendReset(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(v.trim())) return 'Email không hợp lệ';
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.alert.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.alert),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.alert),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),

          // Nút gửi
          AuthButton(
            label: 'Gửi hướng dẫn đặt lại',
            onPressed: _onSendReset,
            isLoading: _isLoading,
            icon: Icons.send_outlined,
          ),

          const SizedBox(height: 24),

          // Quay lại đăng nhập
          Center(
            child: TextButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back,
                  size: 16, color: AppColors.textSecondary),
              label: const Text(
                'Quay lại đăng nhập',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bước 2: Thành công ────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),

        // Icon thành công
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.income.withValues(alpha: 0.1),
                  AppColors.neonCyan.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: AppColors.income,
            ),
          ),
        ),

        const SizedBox(height: 32),

        const Text(
          'Email đã được gửi!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Chúng tôi đã gửi hướng dẫn đặt lại mật khẩu đến\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
            fontFamily: 'Inter',
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Vui lòng kiểm tra hộp thư đến (và thư mục Spam).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: 40),

        // Nút quay lại đăng nhập
        AuthButton(
          label: 'Quay lại đăng nhập',
          onPressed: _goBack,
          icon: Icons.login_rounded,
        ),

        const SizedBox(height: 20),

        // Gửi lại
        Center(
          child: TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {
                _emailSent = false;
                _emailCtrl.clear();
              });
            }),
            child: const Text(
              'Gửi lại email',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
