import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Kết quả tổng hợp cho một hạng mục trong biểu đồ tròn.
class CategoryStat {
  final String category;
  final double total;
  final double percentage; // 0.0 → 100.0
  final Color color;

  const CategoryStat({
    required this.category,
    required this.total,
    required this.percentage,
    required this.color,
  });
}

/// Service tổng hợp dữ liệu giao dịch thành các cấu trúc phù hợp cho biểu đồ.
class ChartService {
  ChartService._();

  // ── Bảng màu Neon cho từng hạng mục ──────────────────────────────────────

  static const Map<String, Color> _categoryColors = {
    'Ăn uống':   Color(0xFF00D4FF), // neon cyan
    'Di chuyển': Color(0xFFBB86FC), // neon purple
    'Mua sắm':   Color(0xFFFF9500), // neon orange
    'Giải trí':  Color(0xFF00FF9D), // neon green
    'Sức khỏe':  Color(0xFFFF4D6A), // neon red
    'Hóa đơn':   Color(0xFFFFD60A), // neon yellow
    'Thu nhập':  Color(0xFF30D158), // green
    'Khác':      Color(0xFF636366), // gray
  };

  /// Màu fallback khi hạng mục không có trong bảng.
  static Color colorFor(String category) =>
      _categoryColors[category] ?? _categoryColors['Khác']!;

  // ── Tổng hợp chi tiêu theo hạng mục ──────────────────────────────────────

  /// Nhận [transactions], trả về Map<category, total> chỉ gồm chi tiêu (isExpense).
  /// Sắp xếp giảm dần theo tổng tiền.
  static Map<String, double> buildCategoryTotals(
    List<Transaction> transactions,
  ) {
    final map = <String, double>{};

    for (final t in transactions) {
      if (!t.isExpense) continue; // bỏ qua thu nhập
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }

    // Sắp xếp giảm dần
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  /// Chuyển Map<category, total> thành List<CategoryStat> kèm màu và %.
  static List<CategoryStat> buildCategoryStats(
    Map<String, double> totals,
  ) {
    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (grandTotal == 0) return [];

    return totals.entries.map((e) {
      return CategoryStat(
        category:   e.key,
        total:      e.value,
        percentage: (e.value / grandTotal) * 100,
        color:      colorFor(e.key),
      );
    }).toList();
  }

  /// Shortcut: từ List<Transaction> → List<CategoryStat> một bước.
  static List<CategoryStat> fromTransactions(List<Transaction> transactions) {
    final totals = buildCategoryTotals(transactions);
    return buildCategoryStats(totals);
  }
}
