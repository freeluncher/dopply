// =============================================================================
// Simplified Routes Configuration with Go Router
// =============================================================================

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import 'package:dopply_app/screens/auth/login_screen.dart';
import 'package:dopply_app/screens/auth/register_screen.dart';
import 'package:dopply_app/screens/dashboard/patient_dashboard.dart';
import 'package:dopply_app/screens/dashboard/doctor_dashboard.dart';
import 'package:dopply_app/screens/dashboard/admin_dashboard.dart';
import 'package:dopply_app/screens/shared/error_screen.dart';
import 'package:dopply_app/screens/monitoring/monitoring_screen.dart';
import 'package:dopply_app/screens/history/history_screen.dart';
import 'package:dopply_app/screens/shared/splash_screen.dart';
import 'package:dopply_app/screens/profile/edit_profile_screen.dart';
import 'package:dopply_app/screens/profile/edit_doctor_profile_screen.dart';
import 'package:dopply_app/screens/notifications/doctor_notifications_screen.dart';
import 'package:dopply_app/screens/admin/doctor_verification_screen.dart';

// Services
import 'package:dopply_app/core/storage.dart';

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isLoggedIn = await StorageService.isLoggedIn();
      final currentLocation = state.fullPath ?? '/';

      // List of protected routes
      final protectedRoutes = [
        '/patient',
        '/doctor',
        '/admin',
        '/monitoring',
        '/history',
        '/patients',
        '/add-patient',
        '/notifications',
        '/doctor/notifications',
        '/verify-doctors',
        '/system-overview',
        '/edit_profile',
        '/settings',
      ];

      // If not logged in and trying to access protected routes
      if (!isLoggedIn &&
          protectedRoutes.any((r) => currentLocation.startsWith(r))) {
        return '/login';
      }

      // Semua user bisa akses /login, /register, /splash tanpa redirect
      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Dashboard routes
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientDashboard(),
      ),
      GoRoute(
        path: '/doctor',
        builder: (context, state) => const DoctorDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),

      // Monitoring routes
      GoRoute(
        path: '/monitoring',
        builder: (context, state) => const PatientMonitoringScreen(),
      ),

      // History routes
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),

      // Doctor-specific routes
      GoRoute(
        path: '/patients',
        builder:
            (context, state) => const ErrorScreen(
              message: 'Halaman daftar pasien belum diimplementasi',
              showRetryButton: false,
            ),
      ),
      GoRoute(
        path: '/add-patient',
        builder:
            (context, state) => const ErrorScreen(
              message: 'Halaman tambah pasien belum diimplementasi',
              showRetryButton: false,
            ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const DoctorNotificationsScreen(),
      ),
      GoRoute(
        path: '/doctor/notifications',
        builder: (context, state) => const DoctorNotificationsScreen(),
      ),

      // Admin-specific routes
      GoRoute(
        path: '/verify-doctors',
        builder: (context, state) => const DoctorVerificationScreen(),
      ),
      GoRoute(
        path: '/system-overview',
        builder:
            (context, state) => const ErrorScreen(
              message: 'Halaman ringkasan sistem belum diimplementasi',
              showRetryButton: false,
            ),
      ),

      // Edit profile route
      GoRoute(
        path: '/edit_profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Edit doctor profile route
      GoRoute(
        path: '/settings',
        builder: (context, state) => const EditDoctorProfileScreen(),
      ),
    ],
    errorBuilder:
        (context, state) => ErrorScreen(
          message:
              'Halaman tidak ditemukan: ${state.error?.toString() ?? 'Unknown error'}',
          showRetryButton: true,
          onRetry: () => context.go('/splash'),
        ),
  );
});

// Navigation helper methods
class AppNavigation {
  static void toLogin(BuildContext context) => context.go('/login');
  static void toRegister(BuildContext context) => context.go('/register');

  static void toDashboard(BuildContext context, String userRole) {
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
  }

  static void toMonitoring(BuildContext context) => context.go('/monitoring');
  static void toHistory(BuildContext context) => context.go('/history');
  static void toPatients(BuildContext context) => context.go('/patients');
  static void toAddPatient(BuildContext context) => context.go('/add-patient');
  static void toNotifications(BuildContext context) =>
      context.go('/notifications');
  static void toVerifyDoctors(BuildContext context) =>
      context.go('/verify-doctors');
  static void toSystemOverview(BuildContext context) =>
      context.go('/system-overview');
  static void toEditProfile(BuildContext context) =>
      context.go('/edit_profile');
  static void toSettings(BuildContext context) => context.go('/settings');
}
