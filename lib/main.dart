// =============================================================================
// Main App Entry Point - Simplified with Routing and Theme
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    print('UNCAUGHT ASYNC ERROR:');
    print(error);
    print(stack);
    return true;
  };
  runApp(const ProviderScope(child: DopplyApp()));
}

class DopplyApp extends ConsumerWidget {
  const DopplyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Dopply - Fetal Monitoring App',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
    );
  }
}
