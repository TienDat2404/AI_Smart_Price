import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/goal.dart';
import '../wallet/wallet_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal     = Color(0xFF00897B);
const _tealDark = Color(0xFF00695C);
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);
const _bg       = Color(0xFFF5F7FA);

// ── Quick category presets ────────────────────────────────────────────────────
class _Preset {
  final String label;
  final IconData icon;
  final Color color;
  const _Preset(this.label, this.icon, this.color);
}

const _presets = [
  _Preset('Du lịch',   Icons.flight,          Color(0xFF1565C0)),
  _Preset('Nhà cửa',   Icons.home_outlined,   Color(0xFF2E7D32)),
  _Preset('Xe cộ',     Icons.two_wheeler,     Color(0xFFFF9800)),
  _Preset('Học vấn',   Icons.school_outlined, Color(0xFF7B1FA2)),
  _Preset('Công nghệ', Icons.phone_iphone,    Color(0xFF0277BD)),
  _Preset('Sức khỏe',  Icons.favorite_border, Color(0xFFC62828)),
  _Preset('Khác',      Icons.star_border,     Color(0xFF455A64)),
];

// ── Show helper ───────────────────────────────────────────────────────────────
Future<Goal?> showAddGoalSheet(BuildContext context) {
  return showModalBottomSheet<Goal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddGoalSheet(),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────
class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();
  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  int _selectedPreset = 0;
  bool _autoSave = false;
  int _selectedWallet = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;

  // AI suggestion: monthly saving needed
  double get _monthlySaving {
    final months = _deadline.difference(DateTime.now()).inDays / 30;
    if (months <= 0 || _amount <= 0) return 0;
    return _amount / months;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _onSave() {
    if (_titleCtrl.text.trim().isEmpty || _amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên và số tiền mục tiêu.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);

    final preset = _presets[_selectedPreset];
    final newGoal = Goal(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      targetAmount: _amount,
      currentAmount: 0,
      deadline: _deadline,
      categoryIcon: preset.icon,
      color: preset.color,
      aiInsight: 'Cần tiết kiệm ${_fmtD(_monthlySaving)} đ/tháng để đạt mục tiêu đúng hạn.',
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop(newGoal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Handle ──────────────────────────────────────────────────────────
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────────────
          Row(children: [
            GestureDetector(
              onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              }),
              child: const Text('Hủy', style: TextStyle(fontSize: 15, color: _textGrey, fontWeight: FontWeight.w600)),
            ),
            const Expanded(
              child: Text('Mục tiêu mới', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
            ),
            const Icon(Icons.mic_none, color: _textGrey, size: 22),
          ]),
          const SizedBox(height: 20),

          // ── Quick presets ────────────────────────────────────────────────────
          const Text('Chọn nhanh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = _presets[i];
                final selected = i == _selectedPreset;
                return GestureDetector(
                  onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedPreset = i);
                  }),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: selected ? p.color : p.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: p.color, width: 2.5) : null,
                        boxShadow: selected ? [BoxShadow(color: p.color.withValues(alpha: 0.35), blurRadius: 10)] : null,
                      ),
                      child: Icon(p.icon, color: selected ? Colors.white : p.color, size: 22),
                    ),
                    const SizedBox(height: 5),
                    Text(p.label, style: TextStyle(fontSize: 10, color: selected ? p.color : _textGrey, fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Title field ──────────────────────────────────────────────────────
          const Text('Tên mục tiêu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 8),
          _InputBox(
            child: TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 15, color: _textDark),
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Mua Laptop mới',
                hintStyle: TextStyle(color: _textGrey),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Amount field ─────────────────────────────────────────────────────
          const Text('Số tiền mục tiêu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 8),
          _InputBox(
            child: Row(children: [
              const Text('d', style: TextStyle(fontSize: 20, color: _textGrey, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Deadline ─────────────────────────────────────────────────────────
          const Text('Ngày hoàn thành', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: _InputBox(
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, color: _teal, size: 18),
                const SizedBox(width: 10),
                Text(
                  '${_deadline.day.toString().padLeft(2, '0')}/${_deadline.month.toString().padLeft(2, '0')}/${_deadline.year}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: _textGrey, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── AI suggestion ────────────────────────────────────────────────────
          if (_amount > 0 && _monthlySaving > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.smart_toy_outlined, color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dựa trên thu nhập hiện tại, bạn cần tiết kiệm khoảng ${_fmtD(_monthlySaving)} đ/tháng để đạt mục tiêu này đúng hạn.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0), height: 1.5),
                  ),
                ),
              ]),
            ),
          if (_amount > 0 && _monthlySaving > 0) const SizedBox(height: 16),

          // ── Auto save switch ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.autorenew, color: _teal, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tiết kiệm tự động', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                  Text('Tự động trích tiền hàng tháng', style: TextStyle(fontSize: 11, color: _textGrey)),
                ]),
              ),
              Switch(value: _autoSave, onChanged: (v) => setState(() => _autoSave = v), activeColor: _teal),
            ]),
          ),

          // ── Wallet selector (when auto save on) ──────────────────────────────
          if (_autoSave) ...[
            const SizedBox(height: 12),
            const Text('Chọn ví nguồn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
            const SizedBox(height: 8),
            ...mockWallets.asMap().entries.map((e) {
              final i = e.key; final w = e.value;
              return GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedWallet = i);
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: i == _selectedWallet ? _teal.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == _selectedWallet ? _teal : Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(w.icon, color: i == _selectedWallet ? _teal : _textGrey, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(w.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == _selectedWallet ? _teal : _textDark))),
                    Text('${_fmtD(w.balance)} d', style: const TextStyle(fontSize: 12, color: _textGrey)),
                    if (i == _selectedWallet) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, color: _teal, size: 16)],
                  ]),
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // ── Primary button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00BCD4), _teal], begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _onSave,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
                label: Text(_isSaving ? 'Đang lưu...' : 'Bắt đầu tiết kiệm',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  foregroundColor: Colors.white, shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Input box wrapper ─────────────────────────────────────────────────────────
class _InputBox extends StatelessWidget {
  final Widget child;
  const _InputBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

String _fmtD(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
