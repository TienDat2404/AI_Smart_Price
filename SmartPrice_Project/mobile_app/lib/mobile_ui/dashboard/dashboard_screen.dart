import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/data/mock_data.dart';
import '../../core/models/budget.dart';
import '../../core/models/transaction.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/widgets/mobile_layout.dart';
import '../analytics/analytics_screen.dart';
import '../budget/budget_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../scan/scan_receipt_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../smart_input/smart_input_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../wallet/wallet_model.dart';
import '../wallet/wallet_screen.dart';
import '../../core/services/balance_notifier.dart';
import '../../core/services/current_user.dart';
import '../voice/voice_assistant_screen.dart';

// ── Teal color palette ────────────────────────────────────────────────────────
const _teal = Color(0xFF00897B);
const _tealLight = Color(0xFFE0F2F1);
const _tealMid = Color(0xFF4DB6AC);
const _bg = Color(0xFFF5F7FA);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);
const _red = Color(0xFFE53935);
const _green = Color(0xFF43A047);
const _orange = Color(0xFFFB8C00);

class _HomeData {
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final double balance;
  const _HomeData({
    required this.transactions,
    required this.budgets,
    required this.balance,
  });
}

// ── DashboardScreen ───────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_HomeData> _future;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Lắng nghe BalanceNotifier — rebuild ngay khi có giao dịch mới
    BalanceNotifier.instance.addListener(_onBalanceChanged);
  }

  @override
  void dispose() {
    BalanceNotifier.instance.removeListener(_onBalanceChanged);
    super.dispose();
  }

  void _onBalanceChanged() {
    // Rebuild _future với balance mới từ mockWallets (không cần gọi API)
    if (mounted) setState(() => _future = _load());
  }

  Future<_HomeData> _load() async {
    final uid = await CurrentUser.id;
    double walletBalance = BalanceNotifier.instance.totalBalance;

    try {
      final bankData = await ApiService.instance.getBankBalance(uid);
      final hasBankLink = bankData['hasBankLink'] as bool? ?? false;

      if (hasBankLink) {
        final bankBalance = (bankData['balance'] as num?)?.toDouble() ?? 0.0;
        if (bankBalance > 0) {
          walletBalance = bankBalance;
        } else {
          final apiBalance = await ApiService.instance.getWalletBalance(uid);
          if (apiBalance > 0) walletBalance = apiBalance;
        }
      } else {
        final apiBalance = await ApiService.instance.getWalletBalance(uid);
        if (apiBalance > 0) walletBalance = apiBalance;
      }
    } catch (_) {
      try {
        final uid2 = await CurrentUser.id;
        final apiBalance = await ApiService.instance.getWalletBalance(uid2);
        if (apiBalance > 0) walletBalance = apiBalance;
      } catch (_) {}
    }

    try {
      final results = await Future.wait([
        ApiService.instance.getTransactions(uid),
        MockData.fetchBudgets(),
      ]);
      final txs     = results[0] as List<Transaction>;
      final budgets = results[1] as List<Budget>;
      return _HomeData(transactions: txs, budgets: budgets, balance: walletBalance);
    } catch (_) {
      // Chỉ dùng mock data khi API hoàn toàn không kết nối được
      // (không fallback khi user mới chỉ chưa có data)
      return _HomeData(transactions: const [], budgets: const [], balance: walletBalance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: MobileLayout(
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: c.teal));
            }
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, color: c.red, size: 48),
                  const SizedBox(height: 12),
                  Text('${snap.error}', textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: c.teal),
                    onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _future = _load());
                    }),
                    child: const Text('Thử lại'),
                  ),
                ]),
              );
            }
            final data = snap.data!;
            return RefreshIndicator(
              color: _teal,
              onRefresh: () async => setState(() => _future = _load()),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(),
                    const SizedBox(height: 16),
                    _AiSearchBar(
                      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SmartInputScreen()))
                          .then((saved) {
                            if (saved == true && mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _future = _load());
                              });
                            }
                          });
                      }),
                      onMicTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          showVoiceAssistant(context).then((saved) {
                            if (saved == true && mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _future = _load());
                              });
                            }
                          });
                        }
                      }),
                    ),
                    const SizedBox(height: 20),
                    _BalanceCard(balance: data.balance, transactions: data.transactions),
                    const SizedBox(height: 20),
                    _AiAdvisorySection(transactions: data.transactions, budgets: data.budgets),
                    const SizedBox(height: 20),
                    _GoalSection(budgets: data.budgets),
                    const SizedBox(height: 20),
                    _RecentTransactionsSection(
                      transactions: data.transactions,
                      onViewAll: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _OcrFab(onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
      })),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _CustomBottomBar(
        currentIndex: _navIndex,
        onTap: (i) {
          // addPostFrameCallback tránh setState/Navigator trong mouse event frame (Windows fix)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _navIndex = i);
            switch (i) {
              case 1:
                Navigator.push(context, _slideRoute(const WalletScreen()))
                    .then((_) {
                      // Reload balance sau khi quay về từ WalletScreen
                      // (user có thể đã chuyển tiền hoặc chỉnh sửa ví)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _future = _load());
                      });
                    });
              case 3:
                Navigator.push(context, _slideRoute(const SavingsGoalsScreen()))
                    .then((_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _future = _load());
                      });
                    });
              case 4:
                Navigator.push(context, _slideRoute(const ProfileScreen()));
            }
          });
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = CurrentUser.cachedName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xin chào,', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          Text(name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
        ]),
        Row(children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: c.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 20,
            backgroundColor: c.tealLight,
            child: Text(initial, style: TextStyle(color: c.teal, fontWeight: FontWeight.bold)),
          ),
        ]),
      ],
    );
  }
}

// ── AI Search Bar ─────────────────────────────────────────────────────────────
class _AiSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onMicTap;
  const _AiSearchBar({required this.onTap, required this.onMicTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: c.cardShadow,
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          Icon(Icons.search, color: c.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Hỏi AI về tài chính của bạn...',
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.teal, _tealMid]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.mic_none, color: c.teal),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onMicTap()),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ]),
      ),
    );
  }
}

// ── Balance Card with Line Chart ──────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double balance;
  final List<Transaction> transactions;
  const _BalanceCard({required this.balance, required this.transactions});

  List<FlSpot> _buildSpots() {
    final now = DateTime.now();
    final Map<int, double> daily = {};
    for (final t in transactions) {
      if (!t.isExpense) continue;
      final diff = now.difference(t.date).inDays;
      if (diff >= 0 && diff < 7) {
        daily[6 - diff] = (daily[6 - diff] ?? 0) + t.amount;
      }
    }
    return List.generate(7, (i) => FlSpot(i.toDouble(), (daily[i] ?? 0) / 1000));
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    final isPositive = balance >= 0;
    final fmt = _fmt(balance.abs());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Tổng tài sản', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('7 ngày', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '${isPositive ? '' : '-'}$fmt d',
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 70,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.white,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _BalanceStat(
            label: 'Thu nhập',
            amount: transactions.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount),
            color: const Color(0xFF80CBC4),
            icon: Icons.arrow_downward,
          ),
          const SizedBox(width: 20),
          _BalanceStat(
            label: 'Chi tiêu',
            amount: transactions.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount),
            color: const Color(0xFFFFCDD2),
            icon: Icons.arrow_upward,
          ),
        ]),
      ]),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _BalanceStat({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(_fmt(amount) + ' d', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

// ── AI Advisory Section ───────────────────────────────────────────────────────
class _AiAdvisorySection extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Budget> budgets;
  const _AiAdvisorySection({required this.transactions, required this.budgets});

  List<_AiCard> _buildCards() {
    final totalExpense = transactions.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final overBudget = budgets.where((b) => b.isOverWarningThreshold).toList();
    return [
      _AiCard(
        icon: Icons.trending_up,
        iconColor: _green,
        title: 'Chi tiêu hôm nay',
        highlight: _fmt(transactions.where((t) => t.isExpense && _isToday(t.date)).fold(0.0, (s, t) => s + t.amount)) + ' d',
        highlightColor: _green,
        subtitle: 'Thấp hơn trung bình 7 ngày',
        action: 'Xem chi tiết',
      ),
      if (overBudget.isNotEmpty)
        _AiCard(
          icon: Icons.warning_amber_rounded,
          iconColor: _red,
          title: 'Cảnh báo ngân sách',
          highlight: overBudget.first.category,
          highlightColor: _red,
          subtitle: 'Đã dùng ${(overBudget.first.progress * 100).toStringAsFixed(0)}% hạn mức',
          action: 'Điều chỉnh',
        ),
      _AiCard(
        icon: Icons.savings_outlined,
        iconColor: _teal,
        title: 'Gợi ý tiết kiệm',
        highlight: _fmt(totalExpense * 0.1) + ' d',
        highlightColor: _teal,
        subtitle: 'Có thể tiết kiệm thêm tháng này',
        action: 'Xem kế hoạch',
      ),
    ];
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cards = _buildCards();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Cố vấn AI nói gì?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.tealLight, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, size: 12, color: c.teal),
            const SizedBox(width: 4),
            Text('AI', style: TextStyle(fontSize: 11, color: c.teal, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _AiCardWidget(card: cards[i]),
        ),
      ),
    ]);
  }
}
class _AiCard {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String highlight;
  final Color highlightColor;
  final String subtitle;
  final String action;
  const _AiCard({
    required this.icon, required this.iconColor, required this.title,
    required this.highlight, required this.highlightColor,
    required this.subtitle, required this.action,
  });
}

class _AiCardWidget extends StatelessWidget {
  final _AiCard card;
  const _AiCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: card.iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(card.icon, color: card.iconColor, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(card.title, style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(card.highlight, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: card.highlightColor)),
          const SizedBox(height: 3),
          Text(card.subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary), maxLines: 2),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: Text(card.action, style: TextStyle(fontSize: 12, color: c.teal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Goal / Progress Section ───────────────────────────────────────────────────
class _GoalSection extends StatelessWidget {
  final List<Budget> budgets;
  const _GoalSection({required this.budgets});

  Color _progressColor(double p) {
    if (p >= 0.9) return _red;
    if (p >= 0.75) return _orange;
    return _teal;
  }

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final daily = budgets.first;
    final others = budgets.skip(1).take(2).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chỉ số mục tiêu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: c.cardShadow,
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Mục tiêu: ${daily.category}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
            Text('${(daily.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _progressColor(daily.progress))),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: daily.progress,
              minHeight: 10,
              backgroundColor: c.tealLight,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor(daily.progress)),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_fmt(daily.spent)} d', style: TextStyle(fontSize: 11, color: c.textSecondary)),
            Text('/ ${_fmt(daily.limit)} d', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: others.map((b) => _CircularGoal(budget: b)).toList(),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _CircularGoal extends StatelessWidget {
  final Budget budget;
  const _CircularGoal({required this.budget});

  Color get _color {
    if (budget.progress >= 0.9) return _red;
    if (budget.progress >= 0.75) return _orange;
    return _teal;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      SizedBox(
        width: 64, height: 64,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: budget.progress,
            strokeWidth: 6,
            backgroundColor: c.tealLight,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
          Text('${(budget.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _color)),
        ]),
      ),
      const SizedBox(height: 6),
      Text(budget.category, style: TextStyle(fontSize: 11, color: c.textSecondary)),
    ]);
  }
}

// ── Recent Transactions — ListView với FadeIn ─────────────────────────────────
class _RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onViewAll;
  const _RecentTransactionsSection({required this.transactions, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final display = ([...transactions]..sort((a, b) => b.date.compareTo(a.date))).take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Giao dịch gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
        GestureDetector(
          onTap: onViewAll,
          child: Text('Xem tất cả', style: TextStyle(fontSize: 13, color: c.teal, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: c.cardShadow,
        ),
        child: display.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Chưa có giao dịch nào.', style: TextStyle(color: c.textSecondary))),
              )
            : Column(
                children: display.asMap().entries.map((e) {
                  final i = e.key;
                  final t = e.value;
                  return Column(children: [
                    _TxRow(transaction: t),
                    if (i < display.length - 1)
                      Divider(height: 1, indent: 64, endIndent: 16, color: c.border),
                  ]);
                }).toList(),
              ),
      ),
    ]);
  }
}

class _TxRow extends StatelessWidget {
  final Transaction transaction;
  const _TxRow({required this.transaction});

  IconData _icon(String cat) {
    switch (cat) {
      case 'An uong': case 'Ăn uống': return Icons.restaurant;
      case 'Di chuyen': case 'Di chuyển': return Icons.directions_bike;
      case 'Mua sam': case 'Mua sắm': return Icons.shopping_bag;
      case 'Giai tri': case 'Giải trí': return Icons.movie;
      case 'Suc khoe': case 'Sức khỏe': return Icons.local_hospital;
      case 'Thu nhap': case 'Thu nhập': return Icons.account_balance_wallet;
      default: return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = transaction;
    final now = DateTime.now();
    final diff = now.difference(t.date).inDays;
    final timeStr = diff == 0 ? 'Hôm nay' : diff == 1 ? 'Hôm qua' : '${t.date.day}/${t.date.month}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: t.isExpense ? const Color(0xFFFFF3E0) : c.tealLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon(t.category), size: 20, color: t.isExpense ? c.orange : c.teal),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.itemName.isNotEmpty ? t.itemName : t.category,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$timeStr · ${t.category}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ])),
        Text(
          '${t.isExpense ? '-' : '+'}${_fmt(t.amount)} d',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: t.isExpense ? c.red : c.green,
          ),
        ),
      ]),
    );
  }
}

// ── Slide transition helper ───────────────────────────────────────────────────
Route<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

// ── OCR FAB ───────────────────────────────────────────────────────────────────
class _OcrFab extends StatelessWidget {
  final VoidCallback onTap;
  const _OcrFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_teal, _tealMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 26),
      ),
    );
  }
}

// ── Custom Bottom Navigation Bar ──────────────────────────────────────────────
class _CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _CustomBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: c.card,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'Trang chủ', index: 0, current: currentIndex, onTap: onTap),
            _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Ví của tôi', index: 1, current: currentIndex, onTap: onTap),
            const SizedBox(width: 60),
            _NavItem(icon: Icons.track_changes, label: 'Mục tiêu', index: 3, current: currentIndex, onTap: onTap),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Cá nhân', index: 4, current: currentIndex, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isActive = index == current;
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap(index)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? c.teal.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: isActive ? c.teal : c.textSecondary),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? c.teal : c.textSecondary, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
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
