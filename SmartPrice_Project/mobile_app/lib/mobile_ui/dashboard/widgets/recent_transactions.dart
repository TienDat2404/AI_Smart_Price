import 'package:flutter/material.dart';
import '../../../core/models/transaction.dart';
import '../../../core/theme/app_colors.dart';

/// Danh sách 5 giao dịch gần nhất trên Dashboard.
class RecentTransactions extends StatelessWidget {
  final List<Transaction> transactions;

  const RecentTransactions({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Lấy 5 giao dịch mới nhất
    final recent = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final display = recent.take(5).toList();

    if (display.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Chưa có giao dịch nào.'),
        ),
      );
    }

    return Column(
      children: display
          .map((t) => _TransactionTile(transaction: t))
          .toList(),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.neonCyan.withValues(alpha: 0.1),
          child: Icon(_categoryIcon(t.category), color: AppColors.primary, size: 20),
        ),
        title: Text(
          t.note.isNotEmpty ? t.note : t.category,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          t.category,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${t.isExpense ? '-' : '+'}${_formatAmount(t.amount)} đ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: t.isExpense ? AppColors.expense : AppColors.income,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(t.date),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Ăn uống':
        return Icons.restaurant;
      case 'Di chuyển':
        return Icons.directions_bike;
      case 'Mua sắm':
        return Icons.shopping_bag;
      case 'Giải trí':
        return Icons.movie;
      case 'Sức khỏe':
        return Icons.local_hospital;
      case 'Thu nhập':
        return Icons.account_balance_wallet;
      default:
        return Icons.attach_money;
    }
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${date.day}/${date.month}';
  }
}
