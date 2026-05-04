import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'wallet_model.dart';

// ── WalletReportScreen ────────────────────────────────────────────────────────
class WalletReportScreen extends StatefulWidget {
  final WalletModel wallet;
  const WalletReportScreen({super.key, required this.wallet});

  @override
  State<WalletReportScreen> createState() => _WalletReportScreenState();
}

class _WalletReportScreenState extends State<WalletReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartAnim;
  late Animation<double> _chartProgress;
  String _selectedMonth = 'Tháng 10, 2023';

  // Mock balance trend data (31 ngày)
  static final List<double> _trendData = [
    84.2, 83.5, 85.0, 84.8, 86.2, 85.9, 87.1, 86.5, 88.0, 87.3,
    89.2, 88.7, 90.1, 89.5, 91.0, 90.4, 92.3, 91.8, 93.5, 92.9,
    94.2, 93.6, 95.0, 94.4, 96.1, 95.5, 97.2, 96.8, 98.0, 97.4, 98.9,
  ];

  // Top spending categories mock
  static const _topCategories = [
    ('Ăn uống',   Icons.restaurant,       1750000.0),
    ('Mua sắm',   Icons.shopping_bag,      820000.0),
    ('Di chuyển', Icons.directions_bike,   500000.0),
  ];

  double get _changePercent {
    if (_trendData.length < 2) return 0;
    return (_trendData.last - _trendData.first) / _trendData.first * 100;
  }

  @override
  void initState() {
    super.initState();
    _chartAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _chartProgress = CurvedAnimation(parent: _chartAnim, curve: Curves.easeOutCubic);
    _chartAnim.forward();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  // ── Derive theme color from wallet ────────────────────────────────────────
  Color get _primary {
    if (widget.wallet.name.contains('Momo') || widget.wallet.name.contains('MoMo')) {
      return const Color(0xFFC62828); // hồng đậm
    }
    if (widget.wallet.name.contains('Vietcombank')) {
      return const Color(0xFF1565C0); // xanh dương
    }
    return const Color(0xFF00897B); // teal mặc định
  }

  Color get _primaryLight => _primary.withValues(alpha: 0.12);
  Color get _primaryGradientEnd {
    if (widget.wallet.name.contains('Momo') || widget.wallet.name.contains('MoMo')) {
      return const Color(0xFFE91E63);
    }
    if (widget.wallet.name.contains('Vietcombank')) {
      return const Color(0xFF1976D2);
    }
    return const Color(0xFF26A69A);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _changePercent;
    final isPositive = pct >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  _CircleBtn(icon: Icons.chevron_left, onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) Navigator.of(context).pop();
                  })),
                  Expanded(
                    child: Text('Ví ${widget.wallet.name}', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A2340))),
                  ),
                  _CircleBtn(icon: Icons.auto_awesome, onTap: () {}, color: _primary),
                ]),
              ),
            ),

            // ── Balance card ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _primaryGradientEnd],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Month dropdown
                    GestureDetector(
                      onTap: () => _showMonthPicker(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_selectedMonth, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Số dư hiện tại', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${_fmt(widget.wallet.balance)} đ',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('${isPositive ? '+' : ''}${pct.toStringAsFixed(1)}% tháng này',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Trend chart ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('XU HƯỚNG SỐ DƯ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A94A6), letterSpacing: 1.2)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isPositive ? '+' : ''}${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // LineChart with draw animation
                    AnimatedBuilder(
                      animation: _chartProgress,
                      builder: (_, __) {
                        final progress = _chartProgress.value;
                        final visibleCount = (_trendData.length * progress).ceil().clamp(2, _trendData.length);
                        final visibleData = _trendData.sublist(0, visibleCount);

                        return SizedBox(
                          height: 160,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 5,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 15,
                                    getTitlesWidget: (value, _) {
                                      final labels = {0.0: '01 Th.10', 15.0: '15 Th.10', 30.0: '31 Th.10'};
                                      return labels.containsKey(value)
                                          ? Text(labels[value]!, style: const TextStyle(fontSize: 10, color: Color(0xFF8A94A6)))
                                          : const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (spots) => spots.map((s) =>
                                    LineTooltipItem('${s.y.toStringAsFixed(1)}M d',
                                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))).toList(),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: visibleData.asMap().entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                                      .toList(),
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  color: _primary,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [_primary.withValues(alpha: 0.25), _primary.withValues(alpha: 0.0)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Top spending ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Top chi tiêu từ ví này',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A2340))),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: _topCategories.asMap().entries.map((e) {
                        final i = e.key;
                        final (name, icon, amount) = e.value;
                        final maxAmount = _topCategories.map((c) => c.$3).reduce((a, b) => a > b ? a : b);
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(12)),
                                child: Icon(icon, color: _primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2340))),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: amount / maxAmount,
                                    minHeight: 5,
                                    backgroundColor: _primaryLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                                  ),
                                ),
                              ])),
                              const SizedBox(width: 12),
                              Text('-${_fmt(amount)} đ',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                            ]),
                          ),
                          if (i < _topCategories.length - 1)
                            const Divider(height: 1, indent: 68, endIndent: 16),
                        ]);
                      }).toList(),
                    ),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker() {
    const months = ['Tháng 8, 2023', 'Tháng 9, 2023', 'Tháng 10, 2023', 'Tháng 11, 2023'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ...months.map((m) => ListTile(
          title: Text(m, style: TextStyle(fontWeight: m == _selectedMonth ? FontWeight.w700 : FontWeight.normal)),
          trailing: m == _selectedMonth ? Icon(Icons.check, color: _primary) : null,
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedMonth = m);
            Navigator.pop(context);
          }),
        )),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ── Circle button ─────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _CircleBtn({required this.icon, required this.onTap, this.color});

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
        child: Icon(icon, size: 18, color: color ?? const Color(0xFF1A2340)),
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
