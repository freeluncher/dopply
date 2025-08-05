import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigasi langsung ke dashboard sesuai role
void toDashboardByRole(BuildContext context, String? userRoleStr) {
  final role = userRoleFromString(userRoleStr);
  switch (role) {
    case UserRole.doctor:
      context.go('/doctor');
      break;
    case UserRole.patient:
      context.go('/patient');
      break;
    case UserRole.unknown:
      context.go('/');
      break;
  }
}

/// Enum untuk role user agar lebih konsisten
enum UserRole { patient, doctor, unknown }

/// Helper untuk konversi string ke enum
UserRole userRoleFromString(String? role) {
  switch (role) {
    case 'doctor':
      return UserRole.doctor;
    case 'patient':
      return UserRole.patient;
    default:
      return UserRole.unknown;
  }
}

/// Navigasi back sesuai role user
void navigateBackByRole(BuildContext context, String? userRoleStr) {
  final role = userRoleFromString(userRoleStr);
  switch (role) {
    case UserRole.doctor:
      context.go('/doctor');
      break;
    case UserRole.patient:
      context.go('/patient');
      break;
    case UserRole.unknown:
      // Default ke halaman utama atau splash jika role tidak diketahui
      context.go('/');
      break;
  }
}

/// Contoh penggunaan di WillPopScope:
/// onWillPop: () async {
///   navigateBackByRole(context, _userRole);
///   return false;
/// }
