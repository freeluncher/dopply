// =============================================================================
// Authentication Service - Simplified with Dio HTTP Client
// =============================================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/models/user.dart';
import 'package:dopply_app/core/api_client.dart';

// Simple HTTP client for auth
class SimpleHttpClient {
  final Dio _dio;

  SimpleHttpClient() : _dio = Dio() {
    _dio.options.baseUrl = ApiConfig.baseUrl; // Dopply API base URL
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      // Ambil token dari storage jika ada
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e) {
      throw Exception('HTTP request failed: $e');
    }
  }
}

// Authentication service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current user provider
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((
  ref,
) {
  return CurrentUserNotifier();
});

class CurrentUserNotifier extends StateNotifier<User?> {
  CurrentUserNotifier() : super(null);

  void setUser(User user) {
    state = user;
  }

  void clearUser() {
    state = null;
  }

  bool get isLoggedIn => state != null;
  String? get userRole => state?.role;
}

class AuthService {
  final SimpleHttpClient _httpClient;
  final ApiClient _apiClient = ApiClient();

  AuthService() : _httpClient = SimpleHttpClient();

  // Login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post('/login', {
        'email': email,
        'password': password,
      });

      // Cek jika ada access_token dan user info di response
      if (response['access_token'] != null && response['role'] != null) {
        // Simpan token dan user info
        final token = response['access_token'];

        // Simpan seluruh payload JWT + password ke storage
        final userPayload = Map<String, dynamic>.from(response);
        userPayload['password'] = password;
        await StorageService.saveToken(token);
        await StorageService.saveUserData(jsonEncode(userPayload));
        await StorageService.saveUserRole(response['role'] ?? 'patient');
        _apiClient.setAuthToken(token);

        // Build User object for state/global usage
        final user = User(
          id: response['id'] ?? 0,
          email: response['email'] ?? '',
          role: response['role'] ?? 'patient',
          name: response['name'] ?? '',
        );
        return AuthResult.success(user: user, token: token);
      } else {
        // Log error response
        print('[LOGIN ERROR] Response: ${response.toString()}');
        return AuthResult.error(message: 'Login gagal: response tidak valid');
      }
    } catch (e, stack) {
      // Log error and stacktrace
      print('[LOGIN ERROR] Exception: $e');
      print('[LOGIN ERROR] Stacktrace: $stack');
      return AuthResult.error(message: 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Register
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _httpClient.post('/register', {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });
      // Debug log response
      print('[REGISTER] Raw response: ${response.toString()}');

      // Backend mengembalikan access_token, id, email, role, name, dst jika sukses
      if (response['access_token'] != null && response['email'] != null) {
        final token = response['access_token'];
        final user = User(
          id: response['id'] ?? 0,
          email: response['email'] ?? '',
          role: response['role'] ?? 'patient',
          name: response['name'] ?? '',
        );
        // Store auth data
        await StorageService.saveToken(token);
        await StorageService.saveUserData(jsonEncode(response));
        await StorageService.saveUserRole(response['role'] ?? 'patient');
        return AuthResult.success(user: user, token: token);
      } else {
        return AuthResult.error(
          message: response['message'] ?? 'Registrasi gagal',
        );
      }
    } catch (e) {
      print('[REGISTER] Exception: $e');
      return AuthResult.error(message: 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _httpClient.post('/auth/logout', {});
    } catch (e) {
      // Even if API call fails, we still clear local storage
      print('Logout API call failed: $e');
    } finally {
      await StorageService.clearAll();
      // Redirect ke halaman login setelah logout
      // Pastikan context tersedia saat pemanggilan
      // Gunakan navigator jika dipanggil dari widget
      // Contoh: context.go('/login');
    }
  }

  // Get current user from storage
  Future<User?> getCurrentUser() async {
    try {
      final userData = await StorageService.getUserData();
      if (userData != null) {
        final userJson = jsonDecode(userData);
        return User.fromJson(userJson);
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  // Get user role
  Future<String?> getUserRole() async {
    return await StorageService.getUserRole();
  }

  // Refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _httpClient.post('/auth/refresh', {
        'refresh_token': refreshToken,
      });

      if (response['success'] == true) {
        final newToken = response['data']['token'];
        await StorageService.saveToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      print('Token refresh failed: $e');
      return false;
    }
  }
}

// Auth result wrapper
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? token;
  final String? errorMessage;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.token,
    this.errorMessage,
  });

  factory AuthResult.success({required User user, required String token}) {
    return AuthResult._(isSuccess: true, user: user, token: token);
  }

  factory AuthResult.error({required String message}) {
    return AuthResult._(isSuccess: false, errorMessage: message);
  }
}
