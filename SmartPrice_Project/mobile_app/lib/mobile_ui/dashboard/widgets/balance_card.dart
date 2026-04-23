import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/neon_line_painter.dart';

/// Thẻ hiển thị tổng số dư + biểu đồ Neon 7 ngày.
class BalanceCard extends StatelessWidget {
  final double balance;

  /// Tổng chi tiêu mỗi ngày trong 7 ngày gần nhất.
  /// Được tạo bởi [NeonLinePainter.buildDailyTotals].
  final List<double> dailyTotals;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.dailyTotals,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final formattedBalance = _formatCurrency(balance.abs());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng số dư',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '7 ngày',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Số dư ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '' : '-'}$formattedBalance',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isPositive ? AppColors.textPrimary : AppColors.expense,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'đ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Biểu đồ Neon ─────────────────────────────────────────────
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: NeonLinePainter(dataPoints: dailyTotals),
              ),
            ),

            const SizedBox(height: 8),

            // ── Nhãn ngày ────────────────────────────────────────────────
            _DayLabels(count: dailyTotals.length),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    // Định dạng số theo kiểu Việt Nam: 48.250.000
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }
}

/// Hàng nhãn ngày (T2, T3, … Hôm nay) bên dưới biểu đồ.
class _DayLabels extends StatelessWidget {
  final int count;

  const _DayLabels({required this.count});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        final day = now.subtract(Duration(days: count - 1 - i));
        final isToday = i == count - 1;
        final label = isToday ? 'Hôm nay' : weekdays[day.weekday % 7];
        return Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? AppColors.neonCyan : AppColors.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
          ),
        );
      }),
    );
  }
}
