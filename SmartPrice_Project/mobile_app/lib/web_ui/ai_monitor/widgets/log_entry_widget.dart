import 'package:flutter/material.dart';

/// Widget hiển thị một bản ghi log AI (input, output, confidence, timestamp).
class LogEntryWidget extends StatelessWidget {
  final String input;
  final String output;
  final double confidence;
  final DateTime timestamp;

  const LogEntryWidget({
    super.key,
    required this.input,
    required this.output,
    required this.confidence,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: Text('Log Entry — TODO')),
      ),
    );
  }
}
