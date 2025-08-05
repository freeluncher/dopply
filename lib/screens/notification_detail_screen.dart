import 'package:flutter/material.dart';

class NotificationDetailScreen extends StatelessWidget {
  final int recordId;
  const NotificationDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context) {
    // TODO: Integrasi dengan detail monitoring (gunakan recordId)
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Monitoring')),
      body: Center(child: Text('Detail monitoring untuk record ID: $recordId')),
    );
  }
}
