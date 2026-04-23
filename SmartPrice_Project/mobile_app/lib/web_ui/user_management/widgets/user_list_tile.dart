import 'package:flutter/material.dart';

/// Tile hiển thị thông tin một user trong danh sách quản lý.
class UserListTile extends StatelessWidget {
  final String name;
  final String email;
  final bool isActive;
  final VoidCallback onToggleActive;
  final VoidCallback onViewDetail;

  const UserListTile({
    super.key,
    required this.name,
    required this.email,
    required this.isActive,
    required this.onToggleActive,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text('User List Tile — TODO'),
    );
  }
}
