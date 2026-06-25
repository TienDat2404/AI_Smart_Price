import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/current_user.dart';
import '../../core/widgets/mobile_layout.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealLight = Color(0xFFE0F2F1);
const _bg        = Color(0xFFF5F7FA);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

const _categoryColors = <String, Color>{
  'An uong':   Color(0xFF00BCD4),
  'Di chuyen': Color(0xFF7C4DFF),
  'Mua sam':   Color(0xFFFF9800),
  'Giai tri':  Color(0xFF4CAF50),
  'Suc khoe':  Color(0xFFF44336),
  'Hoa don':   Color(0xFFFFD600),
  'Thu nhap':  Color(0xFF00897B),
  'Khac':      Color(0xFF9E9E9E),
};

Color _colorFor(String cat) => _categoryColors[cat] ?? const Color(0xFF9E9E9E);

// ── Data models ───────────────────────────────────────────────────────────────
class _CategoryStat {
  final String category;
  final double total;
  final double percentage;
  const _CategoryStat({required this.category, required this.total, required this.percentage});
}

class _AiAdvice {
  final String advice;
  final String type; // "warning" | "tip" | "default"
  const _AiAdvice({required this.advice, required this.type});
}

// ── Mock data ─────────────────────────────────────────────────────────────────
List<_CategoryStat> _mockStats() {
  const raw = [
    ('An uong',   1750000.0),
    ('Di chuyen', 500000.0),
    ('Mua sam',   820000.0),
    ('Giai tri',  200000.0),
    ('Suc khoe',  350000.0),
  ];
  final total = raw.fold(0.0, (s, e) => s + e.$2);
  return raw.map((e) => _CategoryStat(
    category:   e.$1,
    total:      e.$2,
    percentage: total > 0 ? e.$2 / total * 100 : 0,
  )).toList();
}

_AiAdvice _mockAdvice(List<_CategoryStat> stats) {
  if (stats.isEmpty) {
    return const _AiAdvice(advice: 'Chưa có dữ liệu. Hãy bắt đầu ghi chép chi tiêu!', type: 'default');
  }
  final top = stats.first;
  if (top.category.contains('An uong')) {
    return const _AiAdvice(
      advice: 'Ban dang chi kha nhieu cho an uong. Thu nau an tai nha de tiet kiem them nhe!',
      type: 'tip',
    );
  }
  return _AiAdvice(
    advice: "Hạng mục '${top.category}' chiếm tỷ trọng cao nhất. Hãy theo dõi để quản lý tốt hơn!",
    type: 'default',
  );
}

// ── AnalyticsScreen ───────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<({List<_CategoryStat> stats, _AiAdvice advice})> _future;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<_CategoryStat> stats, _AiAdvice advice})> _load() async {
    final uid = await CurrentUser.id;
    List<_CategoryStat> stats;
    _AiAdvice advice;

    try {
      final json = await ApiService.instance.getCategorySummary(uid);
      final cats = (json['categories'] as List?) ?? [];
      stats = cats.map((c) => _CategoryStat(
        category:   c['category'] as String? ?? 'Khac',
        total:      (c['total'] as num? ?? 0).toDouble(),
        percentage: (c['percentage'] as num? ?? 0).toDouble(),
      )).toList();
    } catch (_) {
      stats = _mockStats();
    }

    try {
      final json = await ApiService.instance.getAiAdvice(uid);
      advice = _AiAdvice(
        advice: json['advice'] as String? ?? '',
        type:   json['adviceType'] as String? ?? 'default',
      );
    } catch (_) {
      advice = _mockAdvice(stats);
    }

    return (stats: stats, advice: advice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Phân tích chi tiêu',
            style: TextStyle(fontWeight: FontWeight.w800, color: _textDark, fontSize: 17)),
        iconTheme: const IconThemeData(color: _teal),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _teal),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _future = _load());
            }),
          ),
        ],
      ),
      body: MobileLayout(
        child: FutureBuilder<({List<_CategoryStat> stats, _AiAdvice advice})>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _teal));
            }
            if (snap.hasError || snap.data == null || snap.data!.stats.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.pie_chart_outline, size: 56, color: _textGrey),
                  const SizedBox(height: 12),
                  const Text('Chưa có dữ liệu phân tích.', style: TextStyle(color: _textGrey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _teal),
                    onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _future = _load());
                    }),
                    child: const Text('Thử lại'),
                  ),
                ]),
              );
            }

            final stats      = snap.data!.stats;
            final advice     = snap.data!.advice;
            final grandTotal = stats.fold(0.0, (s, e) => s + e.total);

            return RefreshIndicator(
              color: _teal,
              onRefresh: () async => setState(() => _future = _load()),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(children: [
                  _SummaryCard(grandTotal: grandTotal, count: stats.length),
                  const SizedBox(height: 20),
                  _PieChartCard(
                    stats: stats,
                    touchedIndex: _touchedIndex,
                    onTouch: (i) => setState(() => _touchedIndex = i),
                  ),
                  const SizedBox(height: 16),
                  // AI Advice Card — ngay dưới biểu đồ
                  _AiAdviceCard(advice: advice),
                  const SizedBox(height: 20),
                  _CategoryListCard(stats: stats, grandTotal: grandTotal),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── AI Advice Card ────────────────────────────────────────────────────────────
class _AiAdviceCard extends StatefulWidget {
  final _AiAdvice advice;
  const _AiAdviceCard({required this.advice});

  @override
  State<_AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends State<_AiAdviceCard> {
  String _displayed = '';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void didUpdateWidget(_AiAdviceCard old) {
    super.didUpdateWidget(old);
    if (old.advice.advice != widget.advice.advice) {
      setState(() { _displayed = ''; _done = false; });
      _startTypewriter();
    }
  }

  void _startTypewriter() {
    final text = widget.advice.advice;
    int i = 0;
    Future.doWhile(() async {
      if (!mounted || i >= text.length) return false;
      await Future.delayed(const Duration(milliseconds: 28));
      if (mounted) setState(() => _displayed = text.substring(0, ++i));
      if (i >= text.length && mounted) setState(() => _done = true);
      return i < text.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = widget.advice.type == 'warning';
    final isTip     = widget.advice.type == 'tip';

    final bgColor     = isWarning ? const Color(0xFFFFF3E0) : _tealLight;
    final borderColor = isWarning ? const Color(0xFFFF9800) : _teal;
    final iconColor   = isWarning ? const Color(0xFFFF9800) : _teal;
    final textColor   = isWarning ? const Color(0xFF795548) : const Color(0xFF004D40);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon AI sparkle
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isWarning
                  ? [const Color(0xFFFF9800), const Color(0xFFFFB74D)]
                  : [_teal, const Color(0xFF26A69A)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.auto_awesome,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                isWarning ? 'Cảnh báo chi tiêu' : isTip ? 'Gợi ý tiết kiệm' : 'Nhận xét AI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor, letterSpacing: 0.3),
              ),
              const SizedBox(width: 6),
              // Blinking cursor khi đang gõ
              if (!_done)
                _BlinkingCursor(color: iconColor),
            ]),
            const SizedBox(height: 5),
            Text(
              _displayed,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.5),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Blinking cursor ───────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 2, height: 12, color: widget.color),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double grandTotal;
  final int count;
  const _SummaryCard({required this.grandTotal, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B), Color(0xFF26A69A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        const Icon(Icons.pie_chart_outline, color: Colors.white, size: 36),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tổng chi tiêu', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text('${_fmt(grandTotal)} d',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          Text('$count hạng mục', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── Pie Chart Card ────────────────────────────────────────────────────────────
class _PieChartCard extends StatelessWidget {
  final List<_CategoryStat> stats;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _PieChartCard({required this.stats, required this.touchedIndex, required this.onTouch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Tỉ lệ chi tiêu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Nhan vao tung phan de xem chi tiet', style: TextStyle(fontSize: 12, color: _textGrey)),
        ),
        const SizedBox(height: 20),

        // Pie chart
        SizedBox(
          height: 220,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                    onTouch(-1);
                    return;
                  }
                  onTouch(response!.touchedSection!.touchedSectionIndex);
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 60,
              sections: stats.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                final isTouched = i == touchedIndex;
                return PieChartSectionData(
                  color: _colorFor(s.category),
                  value: s.total,
                  radius: isTouched ? 72 : 58,
                  showTitle: isTouched,
                  title: '${s.percentage.toStringAsFixed(1)}%',
                  titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  borderSide: isTouched
                      ? BorderSide(color: _colorFor(s.category).withValues(alpha: 0.6), width: 3)
                      : const BorderSide(color: Colors.transparent),
                );
              }).toList(),
            )),

            // Center label
            touchedIndex >= 0 && touchedIndex < stats.length
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(stats[touchedIndex].category,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text('${stats[touchedIndex].percentage.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _colorFor(stats[touchedIndex].category))),
                  ])
                : const Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Chi tiêu', style: TextStyle(fontSize: 12, color: _textGrey)),
                    Text('theo hạng mục', style: TextStyle(fontSize: 11, color: _textGrey)),
                  ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Legend
        Wrap(
          spacing: 12, runSpacing: 8, alignment: WrapAlignment.center,
          children: stats.map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: _colorFor(s.category),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _colorFor(s.category).withValues(alpha: 0.4), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 5),
            Text('${s.category} ${s.percentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
          ])).toList(),
        ),
      ]),
    );
  }
}

// ── Category List Card ────────────────────────────────────────────────────────
class _CategoryListCard extends StatelessWidget {
  final List<_CategoryStat> stats;
  final double grandTotal;
  const _CategoryListCard({required this.stats, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Chi tiết theo hạng mục',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 16),
        ...stats.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Column(children: [
            _CategoryRow(stat: s),
            if (i < stats.length - 1) const SizedBox(height: 14),
          ]);
        }),
      ]),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _CategoryStat stat;
  const _CategoryRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(stat.category);
    return Column(children: [
      Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(stat.category,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark))),
        Text('${_fmt(stat.total)} d',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text('${stat.percentage.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: _textGrey)),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: stat.percentage / 100,
          minHeight: 7,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
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
