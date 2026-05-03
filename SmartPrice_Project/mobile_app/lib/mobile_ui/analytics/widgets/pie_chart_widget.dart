import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/theme/app_colors.dart';

/// Biểu đồ tròn hiển thị tỷ lệ chi tiêu theo hạng mục.
/// Nhận [stats] từ [ChartService.fromTransactions()].
class SpendingPieChart extends StatefulWidget {
  final List<CategoryStat> stats;

  const SpendingPieChart({super.key, required this.stats});

  @override
  State<SpendingPieChart> createState() => _SpendingPieChartState();
}

class _SpendingPieChartState extends State<SpendingPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.stats.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu chi tiêu.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        // ── Biểu đồ tròn ──────────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex =
                            response.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 56,
                  sections: _buildSections(),
                ),
              ),

              // ── Nhãn trung tâm ─────────────────────────────────────────
              _touchedIndex >= 0 && _touchedIndex < widget.stats.length
                  ? _CenterLabel(stat: widget.stats[_touchedIndex])
                  : const _CenterLabel(stat: null),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Legend ────────────────────────────────────────────────────────
        _Legend(stats: widget.stats),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    return widget.stats.asMap().entries.map((entry) {
      final i    = entry.key;
      final stat = entry.value;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 72.0 : 60.0;

      return PieChartSectionData(
        color:      stat.color,
        value:      stat.total,
        radius:     radius,
        showTitle:  isTouched,
        title:      '${stat.percentage.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
        // Hiệu ứng glow khi chạm
        borderSide: isTouched
            ? BorderSide(color: stat.color.withValues(alpha: 0.6), width: 3)
            : const BorderSide(color: Colors.transparent, width: 0),
      );
    }).toList();
  }
}

// ── Center Label ──────────────────────────────────────────────────────────────

class _CenterLabel extends StatelessWidget {
  final CategoryStat? stat;
  const _CenterLabel({required this.stat});

  @override
  Widget build(BuildContext context) {
    if (stat == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chi tiêu',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'theo hạng mục',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat!.category,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${stat!.percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: stat!.color,
          ),
        ),
      ],
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final List<CategoryStat> stats;
  const _Legend({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: stats.map((s) => _LegendItem(stat: s)).toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final CategoryStat stat;
  const _LegendItem({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: stat.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: stat.color.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${stat.category} ${stat.percentage.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
