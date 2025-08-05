import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/core/theme.dart';

class MonitoringResult extends ConsumerWidget {
  const MonitoringResult({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Monitoring'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Monitoring Result Screen - Coming Soon')),
    );
  }
}
