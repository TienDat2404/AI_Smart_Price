import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Vui lòng đồng ý với điều khoản sử dụng.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // 1. Gọi API đăng ký — ApiService.register tự động login và trả LoginResponse
      final response = await ApiService.instance.register(
        name:     _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // 2. Lưu token + thông tin user vào SharedPreferences
      await Future.wait([
        AuthService.instance.saveToken(response.token),
        AuthService.instance.saveUserInfo(
          userId:  response.userId,
          name:    response.name,
          email:   response.email,
          isAdmin: response.isAdmin,
        ),
      ]);

      // 3. Load CurrentUser cache với userId thực của tài khoản mới
      await CurrentUser.load();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = switch (e.statusCode) {
          409 => 'Email này đã được sử dụng. Vui lòng dùng email khác.',
          400 => e.message,
          >= 500 => 'Lỗi máy chủ. Vui lòng thử lại sau.',
          _ => e.message,
        };
      });
    } catch (e) {
      setState(() => _errorMessage = 'Không thể kết nối. Kiểm tra lại kết nối mạng.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

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
              // Back
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 16),

              const AuthHeader(
                title: 'Tạo tài khoản',
                subtitle: 'Bắt đầu hành trình quản lý tài chính thông minh.',
              ),
              const SizedBox(height: 32),

              // Họ tên
              CustomTextField(
                label: 'Họ và tên',
                hint: 'Nguyen Van A',
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
                prefixIcon: Icons.person_outline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ tên';
                  if (v.trim().length < 2) return 'Họ tên quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              CustomTextField(
                label: 'Email',
                hint: 'example@email.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              CustomTextField(
                label: 'Mật khẩu',
                hint: 'Tối thiểu 8 ký tự',
                controller: _passwordCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
                  if (!v.contains(RegExp(r'[0-9]'))) {
                    return 'Mật khẩu phải chứa ít nhất 1 chữ số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm password
              CustomTextField(
                label: 'Xác nhận mật khẩu',
                hint: 'Nhập lại mật khẩu',
                controller: _confirmCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline,
                onSubmitted: (_) => _onRegister(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                  if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Terms
              _TermsCheckbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() {
                  _agreedToTerms = v ?? false;
                  if (_agreedToTerms) _errorMessage = null;
                }),
              ),
              const SizedBox(height: 8),

              // Error
              if (_errorMessage != null) ...[
                Container(
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
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: AppColors.alert),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),

              // Nút đăng ký
              AuthButton(
                label: 'Tạo tài khoản',
                onPressed: _onRegister,
                isLoading: _isLoading,
                icon: Icons.person_add_outlined,
              ),
              const SizedBox(height: 28),

              // Chuyển sang Login
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Da co tai khoan? ',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: _goToLogin,
                      child: const Text(
                        'Dang nhap',
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: BorderSide(
                color: value ? AppColors.primary : AppColors.textSecondary,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Toi dong y voi Dieu khoan su dung va Chinh sach bao mat cua SmartPrice AI.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
