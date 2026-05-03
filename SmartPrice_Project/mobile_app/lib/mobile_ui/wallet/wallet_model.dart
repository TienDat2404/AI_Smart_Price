import 'package:flutter/material.dart';

/// Model ví dùng chung giữa WalletScreen, WalletReportScreen, EditWalletScreen.
class WalletModel {
  final String name;
  final String subtitle;
  double balance;
  final Color color;
  final Color textColor;
  final IconData icon;

  WalletModel({
    required this.name,
    required this.subtitle,
    required this.balance,
    required this.color,
    required this.textColor,
    required this.icon,
  });
}

/// Danh sách ví mock — dùng chung toàn bộ wallet screens
final List<WalletModel> mockWallets = [
  WalletModel(
    name: 'Vietcombank', subtitle: '**** 4521',
    balance: 84200000,
    color: const Color(0xFF1565C0), textColor: Colors.white,
    icon: Icons.account_balance,
  ),
  WalletModel(
    name: 'Tien mat', subtitle: 'Tien mat',
    balance: 12500000,
    color: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32),
    icon: Icons.payments_outlined,
  ),
  WalletModel(
    name: 'MoMo', subtitle: 'Vi dien tu',
    balance: 29050000,
    color: const Color(0xFFFCE4EC), textColor: const Color(0xFFC62828),
    icon: Icons.phone_android,
  ),
];
