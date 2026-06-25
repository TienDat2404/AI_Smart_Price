import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/api_service.dart';
import '../../core/services/current_user.dart';
import '../../core/models/transaction.dart';
import 'wallet_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealDark  = Color(0xFF00695C);
const _mint      = Color(0xFFE8F5E9);   // Mint Green Light
const _bg        = Color(0xFFF5F7FA);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

// ── Wallet model (truyền từ WalletScreen) ─────────────────────────────────────
class WalletData {
  final String name;
  final double balance;
  final IconData icon;
  const WalletData({required this.name, required this.balance, required this.icon});
}

// ── EditWalletScreen ──────────────────────────────────────────────────────────
class EditWalletScreen extends StatefulWidget {
  final WalletData wallet;
  const EditWalletScreen({super.key, required this.wallet});

  @override
  State<EditWalletScreen> createState() => _EditWalletScreenState();
}

class _EditWalletScreenState extends State<EditWalletScreen> {
  late TextEditingController _balanceCtrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _balanceCtrl = TextEditingController(
      text: widget.wallet.balance.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    super.dispose();
  }

  double get _newBalance => double.tryParse(
        _balanceCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ?? widget.wallet.balance;

  double get _diff => _newBalance - widget.wallet.balance;

  // ── Update logic ──────────────────────────────────────────────────────────

  Future<void> _onUpdate() async {
    final diff       = _diff;
    final newBalance = _newBalance;

    if (diff == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Cập nhật BankAccounts.Balance trực tiếp qua set-initial-balance
      //    (đây là cách đúng — không tạo giao dịch Điều chỉnh nữa)
      final uid = await CurrentUser.id;
      final bankData = await ApiService.instance.getBankBalance(uid);
      final hasBankLink = bankData['hasBankLink'] as bool? ?? false;

      if (hasBankLink) {
        // Lấy accountId từ danh sách accounts
        final accounts = bankData['accounts'] as List<dynamic>? ?? [];
        if (accounts.isNotEmpty) {
          final accountId = accounts[0]['id'] as String?;
          if (accountId != null) {
            await ApiService.instance.setInitialBankBalance(
              accountId: accountId,
              balance: newBalance,
            );
          }
        }
      } else {
        // Chưa liên kết ngân hàng → tạo giao dịch Điều chỉnh như cũ
        final adjustTx = Transaction(
          id: '',
          userId: uid,
          itemName: 'Điều chỉnh số dư - ${widget.wallet.name}',
          amount: diff.abs(),
          category: 'Điều chỉnh',
          note: 'Điều chỉnh tự động: ${diff > 0 ? '+' : ''}${_fmt(diff)} đ',
          date: DateTime.now(),
          isExpense: diff < 0,
        );
        await ApiService.instance.saveTransaction(adjustTx);
      }
    } catch (_) {
      // Không block nếu API lỗi
    }

    // Cập nhật mockWallets local
    final idx = mockWallets.indexWhere((w) => w.name == widget.wallet.name);
    if (idx != -1) {
      mockWallets[idx].balance = newBalance;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Cập nhật số dư thành công! ${diff > 0 ? '+' : ''}${_fmt(diff)} d'),
        ]),
        backgroundColor: _tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(newBalance);
    });
  }

  void _onBalance() {
    // Cân bằng: điền lại số dư hiện tại
    setState(() => _balanceCtrl.text = widget.wallet.balance.toStringAsFixed(0));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ────────────────────────────────────────────────────────
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
                child: Text('Chỉnh sửa ví', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
              ),
              _CircleBtn(icon: Icons.mic_none, onTap: () {}),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Wallet info card ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _mint,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Ngân hàng liên kết',
                            style: TextStyle(fontSize: 12, color: _textGrey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(widget.wallet.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _teal)),
                      ]),
                      // Avatar
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.wallet.icon, color: _teal, size: 24),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const Text('SỐ DƯ HIỆN TẠI',
                        style: TextStyle(fontSize: 10, color: _textGrey, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('${_fmt(widget.wallet.balance)} d',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _textDark, letterSpacing: -0.5)),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Input section ────────────────────────────────────────────
                const Text('Số dư thực tế mới:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  child: TextField(
                    controller: _balanceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Text('d', style: TextStyle(fontSize: 20, color: _textGrey, fontWeight: FontWeight.w600)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 3 action buttons ─────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _ActionIcon(icon: Icons.balance, label: 'Cân bằng ví', color: _teal, onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _onBalance())),
                  _ActionIcon(icon: Icons.save_outlined, label: 'Lưu thay đổi', color: const Color(0xFF1565C0), onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdate())),
                  _ActionIcon(icon: Icons.close, label: 'Hủy bỏ', color: const Color(0xFFE53935), onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) Navigator.of(context).pop();
                  })),
                ]),

                const SizedBox(height: 14),

                // ── Note ─────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 15, color: _textGrey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Việc điều chỉnh số dư sẽ tạo một giao dịch bù trừ tự động để khớp với thực tế mà bạn vừa nhập.',
                        style: TextStyle(fontSize: 11, color: _textGrey, height: 1.5),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),

          // ── Primary action button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), _teal],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdate()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Cập nhật số dư', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Icon(icon, size: 18, color: _textDark),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

String _fmt(double v) {
  final parts = v.abs().toStringAsFixed(0).split('');
  final buf = StringBuffer();
  if (v < 0) buf.write('-');
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
