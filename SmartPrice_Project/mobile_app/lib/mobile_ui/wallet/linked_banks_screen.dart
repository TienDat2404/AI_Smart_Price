import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'link_bank_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal     = Color(0xFF00897B);
const _tealDark = Color(0xFF00695C);
const _bg       = Color(0xFFF5F7FA);
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);

// ─────────────────────────────────────────────────────────────────────────────
/// Màn hình hiển thị danh sách tài khoản ngân hàng đã liên kết.
/// Từ đây người dùng có thể thêm mới hoặc hủy liên kết.
// ─────────────────────────────────────────────────────────────────────────────
class LinkedBanksScreen extends StatefulWidget {
  final String userId;
  const LinkedBanksScreen({super.key, required this.userId});

  @override
  State<LinkedBanksScreen> createState() => _LinkedBanksScreenState();
}

class _LinkedBanksScreenState extends State<LinkedBanksScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getBankAccounts(widget.userId);
      if (mounted) setState(() { _accounts = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlink(String accountId, String bankName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy liên kết?',
            style: TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
        content: Text('Bạn có chắc muốn hủy liên kết tài khoản $bankName?',
            style: const TextStyle(color: _textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hủy liên kết',
                style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.instance.unlinkBankAccount(accountId);
      _showSnack('Đã hủy liên kết $bankName');
      _load();
    } catch (_) {
      _showSnack('Không thể hủy liên kết. Thử lại.', isError: true);
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
              GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.of(context).pop();
                }),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.chevron_left, size: 18, color: _textDark),
                ),
              ),
              const Expanded(
                child: Text('Ngân hàng liên kết',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
              ),
              GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LinkBankScreen(userId: widget.userId),
                    ),
                  );
                  if (result == true) _load();
                }),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ]),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : _accounts.isEmpty
                    ? _EmptyState(
                        onAdd: () => WidgetsBinding.instance
                            .addPostFrameCallback((_) async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LinkBankScreen(userId: widget.userId),
                            ),
                          );
                          if (result == true) _load();
                        }),
                      )
                    : RefreshIndicator(
                        color: _teal,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          children: [
                            // SePay info banner
                            _InfoBanner(),
                            const SizedBox(height: 16),
                            ..._accounts.map((acc) => _BankAccountCard(
                                  account: acc,
                                  onUnlink: () => _unlink(
                                    acc['id'] as String,
                                    acc['bankName'] as String,
                                  ),
                                )),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
          ),
        ]),
      ),

      // FAB thêm tài khoản
      floatingActionButton: _accounts.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: _teal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Thêm ngân hàng',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LinkBankScreen(userId: widget.userId)),
                );
                if (result == true) _load();
              }),
            )
          : null,
    );
  }
}

// ── Bank Account Card ─────────────────────────────────────────────────────────
class _BankAccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onUnlink;
  const _BankAccountCard({required this.account, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final bankName   = account['bankName'] as String? ?? '';
    final accNum     = account['accountNumberMasked'] as String? ?? '';
    final holder     = account['accountHolder'] as String? ?? '';
    final balance    = (account['balance'] as num? ?? 0).toDouble();
    final status     = account['status'] as String? ?? 'active';
    final lastSync   = account['lastSyncAt'] as String?;
    final isActive   = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [const Color(0xFF004D40), _teal]
                  : [Colors.grey.shade600, Colors.grey.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bankName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              Text(accNum,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Hoạt động' : 'Lỗi',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: _textGrey),
              const SizedBox(width: 8),
              Text(holder,
                  style: const TextStyle(
                      fontSize: 13, color: _textDark, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Số dư hiện tại',
                    style: TextStyle(fontSize: 11, color: _textGrey)),
                const SizedBox(height: 2),
                Text('${_fmt(balance)} đ',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _textDark)),
              ]),
              if (lastSync != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Cập nhật lúc',
                      style: TextStyle(fontSize: 11, color: _textGrey)),
                  const SizedBox(height: 2),
                  Text(_formatDate(lastSync),
                      style: const TextStyle(
                          fontSize: 11,
                          color: _textGrey,
                          fontWeight: FontWeight.w500)),
                ]),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history, size: 16, color: _teal),
                  label: const Text('Lịch sử',
                      style: TextStyle(fontSize: 12, color: _teal)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      WidgetsBinding.instance.addPostFrameCallback((_) => onUnlink()),
                  icon: const Icon(Icons.link_off, size: 16,
                      color: Color(0xFFE53935)),
                  label: const Text('Hủy liên kết',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE53935))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE53935)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Info Banner ───────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: _teal, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'SePay tự động đồng bộ giao dịch ngân hàng. Số dư được cập nhật ngay khi có phát sinh.',
            style: TextStyle(fontSize: 12, color: _tealDark, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance, color: _teal, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Chưa có ngân hàng liên kết',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 8),
          const Text(
            'Liên kết tài khoản ngân hàng để tự động ghi nhận giao dịch qua SePay.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textGrey, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                WidgetsBinding.instance.addPostFrameCallback((_) => onAdd()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Liên kết ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmt(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}

String _formatDate(String isoStr) {
  try {
    final dt = DateTime.parse(isoStr).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';
  } catch (_) {
    return isoStr;
  }
}
