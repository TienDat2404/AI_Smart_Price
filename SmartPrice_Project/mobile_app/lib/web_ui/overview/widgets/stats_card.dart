import 'package:flutter/material.dart';

/// Thẻ thống kê tổng quan (tổng User, tổng giao dịch, v.v.) trên Admin Overview.
class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Stats Card — TODO')),
      ),
    );
  }
}
