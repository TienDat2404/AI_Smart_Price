import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget hiển thị một dòng giao dịch — dùng chung cho mobile và web.
class TransactionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String category;
  final String amount;
  final bool isExpense;

  const TransactionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.category,
    required this.amount,
    this.isExpense = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.neonCyan.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(category, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          amount,
          style: TextStyle(
            color: isExpense ? AppColors.expense : AppColors.income,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
