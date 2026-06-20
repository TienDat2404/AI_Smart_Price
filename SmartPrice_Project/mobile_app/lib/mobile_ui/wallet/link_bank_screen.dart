import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal     = Color(0xFF00897B);
const _tealDark = Color(0xFF00695C);
const _bg       = Color(0xFFF5F7FA);
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);

// ── Danh sách ngân hàng hỗ trợ (hiển thị lúc chọn) ───────────────────────────
const _supportedBanks = [
  {'code': 'MBBank',      'name': 'MB Bank',      'color': 0xFF6200EA},
  {'code': 'Techcombank', 'name': 'Techcombank',  'color': 0xFFD50000},
  {'code': 'VPBank',      'name': 'VPBank',       'color': 0xFF00796B},
  {'code': 'BIDV',        'name': 'BIDV',         'color': 0xFF1565C0},
  {'code': 'VietinBank',  'name': 'VietinBank',   'color': 0xFF558B2F},
  {'code': 'Vietcombank', 'name': 'Vietcombank',  'color': 0xFF00695C},
  {'code': 'TPBank',      'name': 'TPBank',       'color': 0xFFF57F17},
  {'code': 'ACB',         'name': 'ACB',          'color': 0xFF0277BD},
  {'code': 'OCB',         'name': 'OCB',          'color': 0xFF00897B},
  {'code': 'MSB',         'name': 'MSB',          'color': 0xFFAD1457},
];

// ─────────────────────────────────────────────────────────────────────────────
/// Màn hình liên kết tài khoản ngân hàng thực qua SePay.
///
/// Người dùng nhập:
///   1. Chọn ngân hàng
///   2. Số tài khoản
///   3. Tên chủ tài khoản
///   4. SePay API Token (lấy từ sepay.vn/user/api-token)
// ─────────────────────────────────────────────────────────────────────────────
class LinkBankScreen extends StatefulWidget {
  final String userId;
  const LinkBankScreen({super.key, required this.userId});

  @override
  State<LinkBankScreen> createState() => _LinkBankScreenState();
}

class _LinkBankScreenState extends State<LinkBankScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _accountCtrl    = TextEditingController();
  final _holderCtrl     = TextEditingController();
  final _tokenCtrl      = TextEditingController();
  bool  _obscureToken   = true;
  bool  _isLoading      = false;

  Map<String, dynamic>? _selectedBank;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _holderCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      _showSnack('Vui lòng chọn ngân hàng', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.instance.linkBankAccount(
        userId:        widget.userId,
        bankName:      _selectedBank!['code'] as String,
        accountNumber: _accountCtrl.text.trim(),
        accountHolder: _holderCtrl.text.trim().toUpperCase(),
        sePayToken:    _tokenCtrl.text.trim(),
      );

      _showSnack('Liên kết thành công!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true); // true = đã liên kết
      });
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Không thể kết nối server. Thử lại sau.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE53935) : _tealDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              _CircleBtn(
                icon: Icons.chevron_left,
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.of(context).pop();
                }),
              ),
              const Expanded(
                child: Text('Liên kết ngân hàng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
              ),
              const SizedBox(width: 38),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Banner ──────────────────────────────────────────────
                  _SePayBanner(),
                  const SizedBox(height: 24),

                  // ── Chọn ngân hàng ──────────────────────────────────────
                  _SectionLabel('Chọn ngân hàng'),
                  const SizedBox(height: 10),
                  _BankPicker(
                    selected: _selectedBank,
                    onSelect: (bank) => setState(() => _selectedBank = bank),
                  ),
                  const SizedBox(height: 20),

                  // ── Số tài khoản ────────────────────────────────────────
                  _SectionLabel('Số tài khoản'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _accountCtrl,
                    hint: 'VD: 0123456789',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.credit_card,
                    validator: (v) =>
                        (v == null || v.trim().length < 6) ? 'Số tài khoản không hợp lệ' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Tên chủ tài khoản ────────────────────────────────────
                  _SectionLabel('Tên chủ tài khoản'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _holderCtrl,
                    hint: 'VD: NGUYEN VAN A',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên chủ tài khoản' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── SePay Token ──────────────────────────────────────────
                  _SectionLabel('SePay API Token'),
                  const SizedBox(height: 4),
                  const Text(
                    'Lấy token tại: sepay.vn → Tài khoản → API Token',
                    style: TextStyle(fontSize: 11, color: _textGrey),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _tokenCtrl,
                    hint: 'Dán token từ SePay...',
                    prefixIcon: Icons.vpn_key_outlined,
                    obscureText: _obscureToken,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: _textGrey, size: 20,
                      ),
                      onPressed: () => setState(() => _obscureToken = !_obscureToken),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 10) ? 'Token không hợp lệ' : null,
                  ),
                  const SizedBox(height: 24),

                  // ── How it works ─────────────────────────────────────────
                  _HowItWorks(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),

          // ── Submit Button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), _teal],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => WidgetsBinding.instance
                          .addPostFrameCallback((_) => _onSubmit()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Liên kết tài khoản',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── SePay Banner ──────────────────────────────────────────────────────────────
class _SePayBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Liên kết qua SePay',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text(
              'Tự động ghi nhận giao dịch ngân hàng thực tế — không cần nhập tay.',
              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Bank Picker ───────────────────────────────────────────────────────────────
class _BankPicker extends StatelessWidget {
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _BankPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _supportedBanks.map((bank) {
        final isSelected = selected?['code'] == bank['code'];
        final color = Color(bank['color'] as int);
        return GestureDetector(
          onTap: () => WidgetsBinding.instance
              .addPostFrameCallback((_) => onSelect(bank)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                Icons.account_balance,
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                bank['name'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _textDark,
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── How It Works ──────────────────────────────────────────────────────────────
class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, size: 16, color: _teal),
          SizedBox(width: 8),
          Text('Cách hoạt động',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
        ]),
        const SizedBox(height: 12),
        ..._steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: const BoxDecoration(
                      color: Color(0xFFE0F2F1), shape: BoxShape.circle),
                  child: Center(
                    child: Text(step['num']!,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _teal)),
                  ),
                ),
                Expanded(
                  child: Text(step['text']!,
                      style: const TextStyle(
                          fontSize: 12, color: _textGrey, height: 1.5)),
                ),
              ]),
            )),
      ]),
    );
  }

  static const _steps = [
    {'num': '1', 'text': 'Đăng ký tài khoản SePay tại sepay.vn và lấy API Token.'},
    {'num': '2', 'text': 'Liên kết tài khoản ngân hàng trong SePay Dashboard.'},
    {'num': '3',
     'text': 'SmartPrice nhận webhook tự động mỗi khi có giao dịch — thu nhập và chi tiêu đều được ghi lại.'},
    {'num': '4', 'text': 'Số dư trong ví SmartPrice luôn khớp với số dư ngân hàng thực tế.'},
  ];
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: _textDark));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textGrey, fontSize: 13),
        prefixIcon: Icon(prefixIcon, color: _teal, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE53935))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
          ],
        ),
        child: Icon(icon, size: 18, color: _textDark),
      ),
    );
  }
}
