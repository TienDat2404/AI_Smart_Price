import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/services/api_service.dart';
import '../../core/services/balance_notifier.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/mobile_layout.dart';
import 'scan_receipt_screen.dart';

// ── Teal palette ──────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealLight = Color(0xFFE0F2F1);
const _tealDark  = Color(0xFF00695C);
const _red       = Color(0xFFE53935);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

// ── Danh mục ──────────────────────────────────────────────────────────────────
const _categories = [
  'Ăn uống',
  'Di chuyển',
  'Mua sắm',
  'Giải trí',
  'Sức khỏe',
  'Hóa đơn',
  'Thu nhập',
  'Khác',
];

// ── Slide transition helper ───────────────────────────────────────────────────
Route<T> slideUpRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ── ConfirmInvoiceScreen ──────────────────────────────────────────────────────
class ConfirmInvoiceScreen extends StatefulWidget {
  final OcrResult ocrResult;
  const ConfirmInvoiceScreen({super.key, required this.ocrResult});

  @override
  State<ConfirmInvoiceScreen> createState() => _ConfirmInvoiceScreenState();
}

class _ConfirmInvoiceScreenState extends State<ConfirmInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedCategory;
  late TextEditingController _storeCtrl;
  late TextEditingController _totalCtrl;
  late TextEditingController _dateCtrl;
  bool _isSaving = false;

  // AI gợi ý category khác với category gốc
  String? get _aiSuggestion {
    final original = widget.ocrResult.category;
    // Giả lập AI gợi ý category khác
    const suggestions = {
      'Mua sắm': 'Giải trí',
      'Ăn uống': 'Sức khỏe',
      'Di chuyển': 'Hóa đơn',
    };
    return suggestions[original];
  }

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.ocrResult.category.isNotEmpty
        ? widget.ocrResult.category
        : 'Khac';
    _storeCtrl = TextEditingController(text: widget.ocrResult.store);
    _totalCtrl = TextEditingController(
        text: widget.ocrResult.total.toStringAsFixed(0));
    _dateCtrl  = TextEditingController(text: widget.ocrResult.date);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    _totalCtrl.dispose();
    _dateCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  // ── Budget check & notification ──────────────────────────────────────────

  /// Kiểm tra tổng chi tiêu tháng này so với hạn mức.
  /// Nếu vượt 80% → gửi local notification.
  Future<void> _checkBudgetAndNotify(double newAmount) async {
    try {
      // Lấy tổng chi tiêu tháng này từ API
      final stats = await ApiService.instance.getTransactionStats('user_01');
      final totalThisMonth = stats.totalExpense + newAmount;

      // Hạn mức mặc định 5.000.000đ — TODO: lấy từ Budget API
      const double monthlyLimit = 5000000;
      final usedPercent = (totalThisMonth / monthlyLimit) * 100;

      debugPrint('[Budget] Used: ${usedPercent.toStringAsFixed(1)}% of limit');

      if (usedPercent >= 80) {
        await NotificationService.instance.showBudgetWarning(
          usedPercent: usedPercent,
          payload: 'analytics',
        );
      }
    } catch (e) {
      // Không block luồng lưu nếu check budget lỗi
      debugPrint('[Budget] Check failed: $e');
    }
  }

  Future<void> _onSave() async {    setState(() => _isSaving = true);
    try {
      final amount = double.tryParse(_totalCtrl.text.replaceAll('.', '')) ?? 0;

      // Tạo Transaction từ dữ liệu đã xác nhận
      final tx = Transaction(
        id: '',
        userId: 'user_01',
        itemName: _storeCtrl.text.trim(),
        amount: amount,
        category: _selectedCategory,
        note: 'Quét hóa đơn - ${widget.ocrResult.invoiceId}',
        date: DateTime.now(),
        isExpense: true,
      );

      // Gọi API lưu vào MongoDB
      await ApiService.instance.saveTransaction(tx);

      // ✅ Cập nhật số dư real-time — trừ/cộng vào mockWallets ngay lập tức
      // Dashboard sẽ nhận được thông báo qua BalanceNotifier và rebuild
      BalanceNotifier.instance.applyTransaction(
        amount:    amount,
        isExpense: tx.isExpense,
      );

      // ── Kiểm tra ngân sách và gửi notification nếu cần ──────────────────
      await _checkBudgetAndNotify(amount);

      if (!mounted) return;
      // popUntil DashboardScreen — dứt khoát, tránh xung đột frame
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đã lưu: ${_storeCtrl.text} - ${_fmt(amount)} đ'),
          ]),
          backgroundColor: _tealDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: _red),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nền gradient mờ
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: MobileLayout(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) Navigator.of(context).pop();
                      }),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Xác nhận hóa đơn',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${(widget.ocrResult.confidence * 100).toStringAsFixed(0)}% AI',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ]),
                ),

                // ── Invoice card ───────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(children: [
                      _InvoiceCard(
                        storeCtrl: _storeCtrl,
                        totalCtrl: _totalCtrl,
                        dateCtrl: _dateCtrl,
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (v) => setState(() => _selectedCategory = v!),
                        invoiceId: widget.ocrResult.invoiceId,
                      ),

                      const SizedBox(height: 16),

                      // ── AI Suggestion card ─────────────────────────────
                      if (_aiSuggestion != null)
                        _AiSuggestionCard(
                          original: _selectedCategory,
                          suggestion: _aiSuggestion!,
                          onAccept: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _selectedCategory = _aiSuggestion!);
                          }),
                        ),

                      const SizedBox(height: 24),

                      // ── Action buttons ─────────────────────────────────
                      _ActionButtons(
                        isSaving: _isSaving,
                        onSave: _onSave,
                        onCancel: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) Navigator.of(context).pop();
                        }),
                      ),

                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Invoice Card ──────────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final TextEditingController storeCtrl, totalCtrl, dateCtrl;
  final String selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final String invoiceId;

  const _InvoiceCard({
    required this.storeCtrl,
    required this.totalCtrl,
    required this.dateCtrl,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        // Header hóa đơn
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_teal, Color(0xFF26A69A)]),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HÓA ĐƠN', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              if (invoiceId.isNotEmpty)
                Text(invoiceId, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ])),
            // Dashed line decoration
            Column(children: List.generate(4, (_) => Container(
              width: 2, height: 6, margin: const EdgeInsets.only(bottom: 3),
              color: Colors.white.withValues(alpha: 0.4),
            ))),
          ]),
        ),

        // Tổng tiền — nổi bật nhất
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Column(children: [
            const Text('TỔNG TIỀN', style: TextStyle(fontSize: 11, color: _textGrey, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(
                child: TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: _red, letterSpacing: -1),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    suffixText: ' d',
                    suffixStyle: TextStyle(fontSize: 18, color: _textGrey, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]),
          ]),
        ),

        const Divider(indent: 20, endIndent: 20),

        // Fields
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _EditableRow(icon: Icons.store_outlined, label: 'Cửa hàng', controller: storeCtrl),
            const SizedBox(height: 14),
            _EditableRow(icon: Icons.calendar_today_outlined, label: 'Ngày', controller: dateCtrl),
            const SizedBox(height: 14),

            // Category dropdown
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.label_outline, size: 18, color: _teal),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 80, child: Text('Hạng mục', style: TextStyle(fontSize: 13, color: _textGrey))),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categories.contains(selectedCategory) ? selectedCategory : _categories.last,
                    isExpanded: true,
                    alignment: AlignmentDirectional.centerEnd,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: onCategoryChanged,
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // Footer dashed
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 1,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1, style: BorderStyle.solid)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome, size: 13, color: _teal),
            const SizedBox(width: 6),
            Text('Nhận diện bởi SmartPrice AI', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ),
      ]),
    );
  }
}

class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;

  const _EditableRow({required this.icon, required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _teal),
      ),
      const SizedBox(width: 12),
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: _textGrey))),
      Expanded(
        child: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      ),
    ]);
  }
}

// ── AI Suggestion Card ────────────────────────────────────────────────────────
class _AiSuggestionCard extends StatelessWidget {
  final String original;
  final String suggestion;
  final VoidCallback onAccept;

  const _AiSuggestionCard({required this.original, required this.suggestion, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gợi ý từ AI', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          RichText(text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.white),
            children: [
              const TextSpan(text: 'Nên đổi thành '),
              TextSpan(text: suggestion, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFFD740))),
              TextSpan(text: ' thay vì $original?', style: const TextStyle(color: Colors.white70)),
            ],
          )),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onAccept()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD740),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Áp dụng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
          ),
        ),
      ]),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave, onCancel;

  const _ActionButtons({required this.isSaving, required this.onSave, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Xac nhan & Luu
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : () => WidgetsBinding.instance.addPostFrameCallback((_) => onSave()),
          icon: isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(isSaving ? 'Đang lưu...' : 'Xác nhận & Lưu', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Huy bo
      SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onCancel()),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Hủy bỏ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    ]);
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
