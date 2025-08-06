// =============================================================================
// API Client Configuration
// =============================================================================

import 'package:dio/dio.dart';

class ApiConfig {
  static const String baseUrl = 'http://192.168.193.44:8000/api/v1';
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  final Dio _dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() : _dio = Dio() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = ApiConfig.headers;
  }

  Dio get dio => _dio;

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}
