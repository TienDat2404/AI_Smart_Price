import 'package:flutter/material.dart';

/// Model mục tiêu tiết kiệm — map từ API backend.
class Goal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final DateTime deadline;
  final IconData categoryIcon;
  final Color color;
  final String aiInsight;
  bool isCompleted;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.categoryIcon,
    required this.color,
    this.aiInsight = '',
    this.isCompleted = false,
  });

  double get progress => targetAmount > 0
      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  double get progressPercent => progress * 100;

  double get remaining =>
      (targetAmount - currentAmount).clamp(0, double.infinity);

  int get daysLeft =>
      deadline.difference(DateTime.now()).inDays.clamp(0, 9999);

  // ── Serialization ────────────────────────────────────────────────────────

  /// Map từ JSON trả về bởi backend (GoalDto)
  factory Goal.fromJson(Map<String, dynamic> json) {
    final iconName = json['categoryIcon'] as String? ?? 'star';
    final colorHex = json['color'] as String? ?? '#1565C0';
    final deadlineStr = json['deadline'] as String? ?? '';

    return Goal(
      id:            json['id'] as String? ?? '',
      title:         json['title'] as String? ?? '',
      targetAmount:  (json['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      deadline:      DateTime.tryParse(deadlineStr) ?? DateTime.now().add(const Duration(days: 90)),
      categoryIcon:  _iconFromName(iconName),
      color:         _colorFromHex(colorHex),
      aiInsight:     json['aiInsight'] as String? ?? '',
      isCompleted:   json['isCompleted'] as bool? ?? false,
    );
  }

  /// Map icon name string → Flutter IconData
  static IconData _iconFromName(String name) {
    switch (name) {
      case 'flight':          return Icons.flight;
      case 'home':            return Icons.home_outlined;
      case 'two_wheeler':     return Icons.two_wheeler;
      case 'school':          return Icons.school_outlined;
      case 'phone_iphone':    return Icons.phone_iphone;
      case 'favorite':        return Icons.favorite_border;
      case 'shield':          return Icons.shield_outlined;
      case 'directions_car':  return Icons.directions_car;
      case 'beach_access':    return Icons.beach_access;
      case 'restaurant':      return Icons.restaurant_outlined;
      default:                return Icons.star_border;
    }
  }

  /// Map icon → string name để lưu lên backend
  static String iconToName(IconData icon) {
    if (icon == Icons.flight)           return 'flight';
    if (icon == Icons.home_outlined)    return 'home';
    if (icon == Icons.two_wheeler)      return 'two_wheeler';
    if (icon == Icons.school_outlined)  return 'school';
    if (icon == Icons.phone_iphone)     return 'phone_iphone';
    if (icon == Icons.favorite_border)  return 'favorite';
    if (icon == Icons.shield_outlined)  return 'shield';
    return 'star';
  }

  /// Parse hex color "#RRGGBB"
  static Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    return const Color(0xFF1565C0);
  }

  /// Chuyển Color → hex string "#RRGGBB"
  static String colorToHex(Color c) {
    return '#${c.r.toInt().toRadixString(16).padLeft(2, '0')}'
           '${c.g.toInt().toRadixString(16).padLeft(2, '0')}'
           '${c.b.toInt().toRadixString(16).padLeft(2, '0')}';
  }
}

/// Mock goals — chỉ dùng khi API không available
final List<Goal> mockGoals = [];
