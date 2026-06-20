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

/// Danh sách ví — chỉ có MB Bank (liên kết thực qua SePay).
/// Balance được cập nhật từ API khi WalletScreen khởi động.
final List<WalletModel> mockWallets = [
  WalletModel(
    name: 'MB Bank',
    subtitle: '**** 1004',
    balance: 0, // sẽ được cập nhật từ API
    color: const Color(0xFF6200EA),
    textColor: Colors.white,
    icon: Icons.account_balance,
  ),
];
