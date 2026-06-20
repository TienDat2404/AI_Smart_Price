import 'package:flutter/material.dart';
import '../../core/models/goal.dart';
import '../../core/models/transaction.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/widgets/mobile_layout.dart';
import 'add_goal_sheet.dart';

const _teal     = Color(0xFF00897B);
const _tealDark = Color(0xFF00695C);
const _bg       = Color(0xFFF5F7FA);
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);

// ── SavingsGoalsScreen ────────────────────────────────────────────────────────
class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});
  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<Goal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.getSavingsGoals('user_01');
      final goals = data.map(Goal.fromJson).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _goals = goals; _loading = false; });
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _goals = List.from(mockGoals); _loading = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _goals.isNotEmpty ? _goals.first : null;
    final others  = _goals.length > 1 ? _goals.sublist(1) : <Goal>[];

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: MobileLayout(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : RefreshIndicator(
                color: _teal,
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    if (primary != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _PriorityGoalCard(
                            goal: primary,
                            onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) _openDetail(primary);
                            }),
                          ),
                        ),
                      )
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(onAdd: _addGoal),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    if (others.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Mục tiêu khác',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 12,
                            mainAxisSpacing: 12, childAspectRatio: 1.1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _SmallGoalCard(
                              goal: others[i],
                              onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) _openDetail(others[i]);
                              }),
                            ),
                            childCount: others.length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    if (_goals.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _AiStrategyCard(goals: _goals),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _teal,
        onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _addGoal();
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  SliverToBoxAdapter _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 52, 20, 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            }),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mục tiêu', style: TextStyle(fontSize: 13, color: _textGrey)),
              Text('Tiết kiệm',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: _textDark),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE0F2F1),
            child: Text('A', style: TextStyle(color: _teal, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  void _openDetail(Goal goal) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GoalDetailScreen(goal: goal, onAmountAdded: _load),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    ).then((_) => _load());
  }

  void _addGoal() async {
    final newGoal = await showAddGoalSheet(context);
    if (newGoal != null && mounted) {
      // Insert local trước để UI responsive
      setState(() => _goals.insert(0, newGoal));
      // Sau đó sync lại từ backend để đảm bảo data đúng
      _load();
    }
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
            decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
            child: const Icon(Icons.savings_outlined, color: _teal, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Chưa có mục tiêu nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 8),
          const Text('Tạo mục tiêu tiết kiệm đầu tiên để bắt đầu!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textGrey, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onAdd()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tạo mục tiêu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal, foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Priority Goal Card ────────────────────────────────────────────────────────
class _PriorityGoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  const _PriorityGoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [goal.color, goal.color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: goal.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('Ưu tiên cao',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(goal.categoryIcon, color: Colors.white, size: 22),
            ),
          ]),
          const SizedBox(height: 14),
          Text(goal.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)} đ',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress, minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${goal.progressPercent.toStringAsFixed(0)}% hoàn thành',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('Còn ${goal.daysLeft} ngày',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          if (goal.aiInsight.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(goal.aiInsight,
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Small Goal Card ───────────────────────────────────────────────────────────
class _SmallGoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  const _SmallGoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(20), boxShadow: c.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: goal.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(goal.categoryIcon, color: goal.color, size: 20),
            ),
            Text('${goal.progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: goal.color)),
          ]),
          const SizedBox(height: 10),
          Text(goal.title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress, minHeight: 6,
              backgroundColor: goal.color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(goal.color),
            ),
          ),
          const SizedBox(height: 4),
          Text('${_fmt(goal.currentAmount)} đ',
              style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ]),
      ),
    );
  }
}

// ── AI Strategy Card ──────────────────────────────────────────────────────────
class _AiStrategyCard extends StatelessWidget {
  final List<Goal> goals;
  const _AiStrategyCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    // Tìm goal gần deadline nhất còn chưa hoàn thành
    final urgent = goals.where((g) => !g.isCompleted && g.daysLeft < 90)
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final focus = urgent.isNotEmpty ? urgent.first : goals.first;
    final months = focus.daysLeft / 30;
    final monthly = months > 0 ? focus.remaining / months : focus.remaining;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: const Color(0xFF1A237E).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Chiến lược từ AI',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            Text('Gợi ý cá nhân hóa',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        Text(
          'Cần tiết kiệm ${_fmt(monthly)}đ/tháng để hoàn thành "${focus.title}" trong ${focus.daysLeft} ngày!',
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
        ),
      ]),
    );
  }
}

// ── Goal Detail Screen ────────────────────────────────────────────────────────
class GoalDetailScreen extends StatefulWidget {
  final Goal goal;
  final VoidCallback? onAmountAdded;
  const GoalDetailScreen({super.key, required this.goal, this.onAmountAdded});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progressAnim;
  late Goal _goal;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progressAnim = Tween<double>(begin: 0, end: _goal.progress)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  Future<void> _addMoney() async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm tiền vào quỹ',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập số tiền (đ)',
            prefixIcon: Icon(Icons.attach_money, color: _teal),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll('.', ''));
              Navigator.pop(context, v);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;

    try {
      // 1. Cập nhật currentAmount của goal trong MongoDB
      final result = await ApiService.instance.addToSavingsGoal(
        goalId: _goal.id,
        amount: amount,
      );
      final updated = Goal.fromJson(result);

      // 2. Tạo giao dịch chi tiêu "Tiết kiệm" → trừ balance tự động
      //    (TransactionsController sẽ trừ BankAccounts.Balance)
      await ApiService.instance.saveTransaction(
        Transaction(
          id: '',
          userId: 'user_01',
          itemName: 'Tiết kiệm - ${_goal.title}',
          amount: amount,
          category: 'Tiết kiệm',
          note: 'Nạp vào mục tiêu: ${_goal.title}',
          date: DateTime.now(),
          isExpense: true,
        ),
      );

      _anim.reset();
      _progressAnim = Tween<double>(begin: _goal.progress, end: updated.progress)
          .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
      setState(() => _goal = updated);
      _anim.forward();
      widget.onAmountAdded?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã thêm ${_fmt(amount)}đ vào quỹ "${_goal.title}"!'),
          backgroundColor: _tealDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      // Cập nhật local nếu API lỗi
      setState(() {
        _goal.currentAmount += amount;
        if (_goal.currentAmount >= _goal.targetAmount) _goal.isCompleted = true;
      });
    }
  }

  Future<void> _withdrawMoney() async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rút tiền từ quỹ',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Số dư trong quỹ: ${_fmt(_goal.currentAmount)}đ',
              style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nhập số tiền rút (đ)',
              prefixIcon: Icon(Icons.remove_circle_outline, color: Color(0xFFE53935)),
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll('.', ''));
              Navigator.pop(context, v);
            },
            child: const Text('Rút'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;
    if (amount > _goal.currentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Số tiền rút vượt quá số dư trong quỹ.'),
        backgroundColor: Color(0xFFE53935),
      ));
      return;
    }

    try {
      final result = await ApiService.instance.withdrawFromSavingsGoal(
        goalId: _goal.id,
        amount: amount,
      );
      final updated = Goal.fromJson(result);

      // Tạo giao dịch thu nhập để cộng lại balance ví
      await ApiService.instance.saveTransaction(
        Transaction(
          id: '',
          userId: 'user_01',
          itemName: 'Rút quỹ - ${_goal.title}',
          amount: amount,
          category: 'Thu nhập',
          note: 'Rút tiền từ mục tiêu: ${_goal.title}',
          date: DateTime.now(),
          isExpense: false,
        ),
      );

      _anim.reset();
      _progressAnim = Tween<double>(begin: _goal.progress, end: updated.progress)
          .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
      setState(() => _goal = updated);
      _anim.forward();
      widget.onAmountAdded?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã rút ${_fmt(amount)}đ từ quỹ "${_goal.title}"!'),
          backgroundColor: _tealDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: const Color(0xFFE53935),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _goal;
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.pop(context);
                }),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.card, borderRadius: BorderRadius.circular(12),
                    boxShadow: context.colors.cardShadow,
                  ),
                  child: Icon(Icons.chevron_left, color: context.colors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(g.title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary),
                  overflow: TextOverflow.ellipsis)),
              if (g.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14),
                    SizedBox(width: 4),
                    Text('Hoàn thành',
                        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [g.color, g.color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(
                      color: g.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Icon(g.categoryIcon, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text('${_fmt(g.currentAmount)} đ',
                        style: const TextStyle(color: Colors.white, fontSize: 32,
                            fontWeight: FontWeight.w900, letterSpacing: -1)),
                    Text('/ ${_fmt(g.targetAmount)} đ',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value, minHeight: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${g.progressPercent.toStringAsFixed(1)}% · Còn ${_fmt(g.remaining)}đ · ${g.daysLeft} ngày',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                if (g.aiInsight.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.card, borderRadius: BorderRadius.circular(16),
                      boxShadow: context.colors.cardShadow,
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome, color: _teal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.aiInsight,
                          style: TextStyle(fontSize: 13, color: context.colors.textPrimary, height: 1.5))),
                    ]),
                  ),
                const SizedBox(height: 20),
                if (!g.isCompleted)
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _addMoney()),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nạp vào quỹ',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _goal.currentAmount > 0
                              ? () => WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _withdrawMoney())
                              : null,
                          icon: const Icon(Icons.remove, size: 18),
                          label: const Text('Rút tiền',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            side: const BorderSide(color: Color(0xFFE53935)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ])
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.celebration, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text('Chúc mừng! Bạn đã đạt mục tiêu!',
                          style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

String _fmt(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
