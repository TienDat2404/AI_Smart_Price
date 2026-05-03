import 'package:flutter/material.dart';
import '../../core/widgets/mobile_layout.dart';
import 'wallet_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealDark  = Color(0xFF00695C);
const _bg        = Color(0xFFF5F7FA);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

// ── TransferScreen ────────────────────────────────────────────────────────────
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String _amount = '0';
  bool _isProcessing = false;

  // Dùng trực tiếp mockWallets — thay đổi sẽ phản ánh lên WalletScreen
  int _fromIdx = 0;
  int _toIdx   = 1;

  double get _amountValue => double.tryParse(_amount) ?? 0;

  // ── Numpad ────────────────────────────────────────────────────────────────

  void _onKey(String key) {
    setState(() {
      if (key == 'DEL') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (key == '000') {
        _amount = _amount == '0' ? '0' : _amount + '000';
      } else {
        _amount = _amount == '0' ? key : _amount + key;
      }
      // Giới hạn 12 chữ số
      if (_amount.length > 12) _amount = _amount.substring(0, 12);
    });
  }

  // ── Transfer logic ────────────────────────────────────────────────────────

  Future<void> _onTransfer() async {
    final amount = _amountValue;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui long nhap so tien hop le.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (amount > mockWallets[_fromIdx].balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('So du ${mockWallets[_fromIdx].name} khong du de chuyen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 800)); // giả lập API

    // ✅ Cập nhật trực tiếp mockWallets — WalletScreen sẽ thấy thay đổi
    mockWallets[_fromIdx].balance -= amount;
    mockWallets[_toIdx].balance   += amount;

    setState(() => _isProcessing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Chuyen ${_fmt(amount)} d thanh cong!'),
        ]),
        backgroundColor: _tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.of(context).pop(); // quay về WalletScreen
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final from = mockWallets[_fromIdx];
    final to   = mockWallets[_toIdx];

    return Scaffold(
      backgroundColor: _bg,
      body: MobileLayout(
        child: SafeArea(
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) Navigator.of(context).pop();
                  }),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textDark),
                  ),
                ),
                const Expanded(
                  child: Text('Chuyen noi bo', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
                ),
                const SizedBox(width: 38),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  // ── Amount card ───────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Column(children: [
                      Text(
                        '${_fmt(_amountValue)} d',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: _textDark, letterSpacing: -1),
                      ),
                      const SizedBox(height: 12),
                      // Flow chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(from.icon, size: 14, color: _teal),
                          const SizedBox(width: 6),
                          Text(from.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 14, color: _teal),
                          ),
                          Icon(to.icon, size: 14, color: _teal),
                          const SizedBox(width: 6),
                          Text(to.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── From / To boxes ───────────────────────────────────────
                  Row(children: [
                    Expanded(child: _WalletBox(label: 'TU', wallet: from, isSource: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _WalletBox(label: 'DEN', wallet: to, isSource: false)),
                  ]),

                  const SizedBox(height: 20),

                  // ── Custom numpad ─────────────────────────────────────────
                  _Numpad(onKey: _onKey),

                  const SizedBox(height: 20),
                ]),
              ),
            ),

            // ── Bottom actions ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(children: [
                // Quay lai
                Expanded(
                  child: GestureDetector(
                    onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) Navigator.of(context).pop();
                    }),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Quay lai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textGrey)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tiep tuc
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isProcessing ? null : () => WidgetsBinding.instance.addPostFrameCallback((_) => _onTransfer()),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF00897B)],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: _isProcessing
                          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('Tiep tuc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Wallet Box ────────────────────────────────────────────────────────────────
class _WalletBox extends StatelessWidget {
  final String label;
  final WalletModel wallet;
  final bool isSource;
  const _WalletBox({required this.label, required this.wallet, required this.isSource});

  @override
  Widget build(BuildContext context) {
    final bg     = isSource ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9);
    final accent = isSource ? const Color(0xFF1565C0) : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(wallet.icon, size: 18, color: accent),
          const SizedBox(width: 6),
          Expanded(child: Text(wallet.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('${_fmt(wallet.balance)} d', style: TextStyle(fontSize: 12, color: accent.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Custom Numpad ─────────────────────────────────────────────────────────────
class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Numpad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', 'DEL'],
    ];

    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: row.map((key) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onKey(key)),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: key == 'DEL' ? const Color(0xFFFFEBEE) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: key == 'DEL'
                        ? const Icon(Icons.backspace_outlined, size: 20, color: Color(0xFFE53935))
                        : Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark)),
                  ),
                ),
              ),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
String _fmt(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
