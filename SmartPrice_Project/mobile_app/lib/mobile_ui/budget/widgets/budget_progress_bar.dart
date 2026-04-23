import 'package:flutter/material.dart';

/// Thanh tiến trình theo dõi ngân sách theo hạng mục.
/// Hiển thị màu đỏ khi [progress] >= 0.8 (vượt 80% ngân sách).
class BudgetProgressBar extends StatelessWidget {
  final String category;
  final double progress; // 0.0 → 1.0
  final String spent;
  final String limit;

  const BudgetProgressBar({
    super.key,
    required this.category,
    required this.progress,
    required this.spent,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Budget Progress Bar — TODO'));
  }
}
