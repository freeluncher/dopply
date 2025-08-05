// =============================================================================
// Splash Screen - Persistent Login Checker
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dopply_app/core/storage.dart';
import 'loading_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    print('[SPLASH] Checking persistent login...');
    final isLoggedIn = await StorageService.isLoggedIn();
    final userRole = await StorageService.getUserRole();
    print('[SPLASH] isLoggedIn: $isLoggedIn, userRole: $userRole');
    if (!mounted) return;
    if (isLoggedIn) {
      switch (userRole) {
        case 'patient':
          context.go('/patient');
          break;
        case 'doctor':
          context.go('/doctor');
          break;
        case 'admin':
          context.go('/admin');
          break;
        default:
          context.go('/patient');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen(
      message: 'Memuat aplikasi...',
      showSpinner: true,
    );
  }
}
