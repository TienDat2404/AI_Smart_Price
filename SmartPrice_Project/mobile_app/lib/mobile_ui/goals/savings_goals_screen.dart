import 'package:flutter/material.dart';
import '../../core/models/goal.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/widgets/mobile_layout.dart';
import 'add_goal_sheet.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
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
  final List<Goal> _goals = List.from(mockGoals);

  @override
  Widget build(BuildContext context) {
    final primary = _goals.isNotEmpty ? _goals.first : null;
    final others  = _goals.length > 1 ? _goals.sublist(1) : <Goal>[];

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: MobileLayout(
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 52, 20, 8),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
                      onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) Navigator.pop(context);
                      }),
                      tooltip: 'Quay lai',
                    ),
                    const SizedBox(width: 2),
                    // Title
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Muc tieu', style: TextStyle(fontSize: 13, color: _textGrey)),
                        Text('Tiet kiem', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark)),
                      ]),
                    ),
                    // Right actions
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: _textDark),
                      onPressed: () {},
                    ),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE0F2F1),
                      child: Text('A', style: TextStyle(color: _teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Priority goal card ───────────────────────────────────────────
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
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Other goals grid ─────────────────────────────────────────────
            if (others.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Muc tieu khac', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _SmallGoalCard(goal: others[i], onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) _openDetail(others[i]);
                    })),
                    childCount: others.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── AI strategy ──────────────────────────────────────────────────
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

      // ── FAB ──────────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: _teal,
        onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _addGoal();
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _openDetail(Goal goal) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GoalDetailScreen(goal: goal),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _addGoal() async {
    final newGoal = await showAddGoalSheet(context);
    if (newGoal != null && mounted) {
      setState(() => _goals.insert(0, newGoal));
    }
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
              child: const Text('Uu tien cao', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(goal.categoryIcon, color: Colors.white, size: 22),
            ),
          ]),
          const SizedBox(height: 14),
          Text(goal.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)} d',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${goal.progressPercent.toStringAsFixed(0)}% hoan thanh',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('Con ${goal.daysLeft} ngay', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          // AI insight
          if (goal.aiInsight.isNotEmpty)
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
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: c.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: goal.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(goal.categoryIcon, color: goal.color, size: 20),
            ),
            Text('${goal.progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: goal.color)),
          ]),
          const SizedBox(height: 10),
          Text(goal.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              backgroundColor: goal.color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(goal.color),
            ),
          ),
          const SizedBox(height: 4),
          Text('${_fmt(goal.currentAmount)} d', style: TextStyle(fontSize: 11, color: c.textSecondary)),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Chien luoc tu AI', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            Text('Goi y ca nhan hoa', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        const Text(
          'Giam chi tieu an ngoai 30% (khoang 500k/thang) se giup ban dat muc tieu "Mua iPhone 16 Pro" som hon 15 ngay!',
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00BCD4), _teal]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('Toi uu hoa ngay', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Goal Detail Screen ────────────────────────────────────────────────────────
class GoalDetailScreen extends StatefulWidget {
  final Goal goal;
  const GoalDetailScreen({super.key, required this.goal});
  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progressAnim = Tween<double>(begin: 0, end: widget.goal.progress)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.pop(context);
                }),
                child: Container(width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: context.colors.cardShadow,
                    ),
                    child: Icon(Icons.chevron_left, color: context.colors.textPrimary)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(g.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colors.textPrimary), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                // Hero card
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [g.color, g.color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Icon(g.categoryIcon, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text('${_fmt(g.currentAmount)} d', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    Text('/ ${_fmt(g.targetAmount)} d', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          minHeight: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${g.progressPercent.toStringAsFixed(1)}% · Con ${_fmt(g.remaining)} d · ${g.daysLeft} ngay',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 20),
                // AI insight
                if (g.aiInsight.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: context.colors.cardShadow,
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome, color: _teal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.aiInsight, style: TextStyle(fontSize: 13, color: context.colors.textPrimary, height: 1.5))),
                    ]),
                  ),
                const SizedBox(height: 20),
                // Add money button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Them tien vao quy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
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
