import 'package:flutter/material.dart';

/// Model mục tiêu tiết kiệm.
class Goal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final DateTime deadline;
  final IconData categoryIcon;
  final Color color;
  final String aiInsight;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.categoryIcon,
    required this.color,
    this.aiInsight = '',
  });

  double get progress => targetAmount > 0
      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  double get progressPercent => progress * 100;

  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);

  int get daysLeft => deadline.difference(DateTime.now()).inDays.clamp(0, 9999);
}

/// Mock goals data
final List<Goal> mockGoals = [
  Goal(
    id: 'g1',
    title: 'Mua iPhone 16 Pro',
    targetAmount: 30000000,
    currentAmount: 18500000,
    deadline: DateTime.now().add(const Duration(days: 60)),
    categoryIcon: Icons.phone_iphone,
    color: const Color(0xFF1565C0),
    aiInsight: 'Du kien hoan thanh trong 2 thang nua neu tiet kiem them 1.9M/thang.',
  ),
  Goal(
    id: 'g2',
    title: 'Du lich Nhat Ban',
    targetAmount: 50000000,
    currentAmount: 12000000,
    deadline: DateTime.now().add(const Duration(days: 180)),
    categoryIcon: Icons.flight,
    color: const Color(0xFF00897B),
    aiInsight: 'Can tiet kiem them 38M trong 6 thang.',
  ),
  Goal(
    id: 'g3',
    title: 'Mua xe may',
    targetAmount: 45000000,
    currentAmount: 30000000,
    deadline: DateTime.now().add(const Duration(days: 90)),
    categoryIcon: Icons.two_wheeler,
    color: const Color(0xFFFF9800),
    aiInsight: 'Da dat 67%, tiep tuc co gang!',
  ),
  Goal(
    id: 'g4',
    title: 'Quy khan cap',
    targetAmount: 20000000,
    currentAmount: 20000000,
    deadline: DateTime.now().add(const Duration(days: 0)),
    categoryIcon: Icons.shield_outlined,
    color: const Color(0xFF43A047),
    aiInsight: 'Da hoan thanh muc tieu!',
  ),
];
