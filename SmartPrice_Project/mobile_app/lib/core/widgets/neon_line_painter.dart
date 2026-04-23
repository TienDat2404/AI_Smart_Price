import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Vẽ đường biểu đồ Neon từ danh sách điểm dữ liệu thực tế.
///
/// Cách dùng:
/// ```dart
/// // 1. Tính tổng chi tiêu mỗi ngày trong 7 ngày gần nhất
/// final dailyTotals = NeonLinePainter.buildDailyTotals(transactions);
///
/// // 2. Truyền vào CustomPaint
/// CustomPaint(painter: NeonLinePainter(dataPoints: dailyTotals))
/// ```
class NeonLinePainter extends CustomPainter {
  /// Danh sách tổng chi tiêu theo ngày, index 0 = ngày xa nhất, index cuối = hôm nay.
  /// Nếu null hoặc rỗng, vẽ đường mặc định minh họa.
  final List<double>? dataPoints;
  final Color color;
  final Color fillColor;
  final double strokeWidth;

  const NeonLinePainter({
    this.dataPoints,
    this.color = AppColors.neonCyan,
    this.fillColor = const Color(0x1A00BCD4), // neonCyan 10% opacity
    this.strokeWidth = 3,
  });

  /// Helper: nhận List<Transaction> 7 ngày, trả về List<double> 7 phần tử
  /// (tổng chi tiêu mỗi ngày, index 0 = 6 ngày trước, index 6 = hôm nay).
  static List<double> buildDailyTotals(
    List<dynamic> transactions, {
    int days = 7,
  }) {
    final now = DateTime.now();
    final totals = List<double>.filled(days, 0.0);

    for (final t in transactions) {
      // Chỉ tính giao dịch chi tiêu
      if (!(t.isExpense as bool)) continue;

      final diff = now.difference(t.date as DateTime).inDays;
      if (diff >= 0 && diff < days) {
        // diff=0 → hôm nay → index cuối (days-1)
        totals[(days - 1) - diff] += (t.amount as double);
      }
    }
    return totals;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = _resolvePoints(size);

    // ── Fill gradient bên dưới đường ──────────────────────────────────────
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, const Color(0x0000BCD4)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
    _addCurveToPath(fillPath, points);
    fillPath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    // ── Đường Neon chính ──────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    _addCurveToPath(linePath, points);
    canvas.drawPath(linePath, linePaint);

    // ── Chấm tròn tại mỗi điểm dữ liệu ──────────────────────────────────
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  /// Chuyển dataPoints thành tọa độ canvas, chuẩn hóa theo min/max.
  List<Offset> _resolvePoints(Size size) {
    final raw = (dataPoints != null && dataPoints!.isNotEmpty)
        ? dataPoints!
        : [0.7, 0.8, 0.4, 0.6, 0.1, 0.3, 0.2]; // fallback minh họa

    final maxVal = raw.reduce((a, b) => a > b ? a : b);
    final minVal = raw.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs();

    final n = raw.length;
    return List.generate(n, (i) {
      final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
      // Giá trị cao → y nhỏ (gần đỉnh canvas)
      final normalized = range == 0 ? 0.5 : (raw[i] - minVal) / range;
      final y = size.height * (1.0 - normalized * 0.8 - 0.1); // padding 10%
      return Offset(x, y);
    });
  }

  /// Vẽ đường cong Catmull-Rom qua các điểm.
  void _addCurveToPath(Path path, List<Offset> pts) {
    if (pts.length < 2) return;
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
  }

  @override
  bool shouldRepaint(covariant NeonLinePainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
