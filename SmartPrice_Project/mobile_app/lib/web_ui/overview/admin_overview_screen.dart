import 'package:flutter/material.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Overview')),
      body: const Center(child: Text('Admin Overview Screen')),
    );
  }
}
