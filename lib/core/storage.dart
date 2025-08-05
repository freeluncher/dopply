// =============================================================================
// Simplified Secure Storage Service
// =============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  // Monitoring history management
  static const String _monitoringHistoryKey = 'monitoring_history';

  static Future<void> saveMonitoringHistory(String historyJson) async {
    await _storage.write(key: _monitoringHistoryKey, value: historyJson);
  }

  static Future<String?> getMonitoringHistory() async {
    return await _storage.read(key: _monitoringHistoryKey);
  }

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _userRoleKey = 'user_role';

  // Token management
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // User data management
  static Future<void> saveUserData(String userData) async {
    await _storage.write(key: _userKey, value: userData);
  }

  static Future<String?> getUserData() async {
    return await _storage.read(key: _userKey);
  }

  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  // Alias for compatibility with monitoring_screen.dart
  static Future<String?> getRole() async {
    return await getUserRole();
  }

  // Clear all data (for logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final token = await getToken();
      debugPrint('[STORAGE] isLoggedIn: token=$token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('[STORAGE] ERROR isLoggedIn: ' + e.toString());
      return false;
    }
  }
}
