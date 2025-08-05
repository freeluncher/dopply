import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:dio/dio.dart';
import 'package:dopply_app/core/storage.dart';
import 'dart:convert';
import 'package:dopply_app/services/auth_service.dart';

final patientServiceProvider = Provider<PatientService>((ref) {
  return PatientService();
});

class PatientService {
  // Fetch single patient profile by ID
  Future<Patient?> getPatientProfile(int patientId) async {
    print('[PatientService] Fetching patient profile for ID: $patientId');
    try {
      // Ambil token dari storage
      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        print('[PatientService] No token found, cannot authenticate');
        return null;
      }
      // Kirim header Authorization
      final response = await _apiClient.dio.get(
        '/patient/$patientId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print(
        '[PatientService] Profile response: \\${response.statusCode} \\${response.data}',
      );
      if (response.statusCode == 200 && response.data != null) {
        // Ambil data pasien dari key 'patient' jika ada
        final patientJson = response.data['patient'] ?? response.data;
        return Patient.fromJson(patientJson);
      } else {
        print(
          '[PatientService] Failed to fetch patient profile: status \\${response.statusCode}',
        );
        return null;
      }
    } catch (e, st) {
      print('[PatientService] Error fetching patient profile: $e');
      // If the primary endpoint fails (405), try alternative approach
      if (e.toString().contains('405') ||
          e.toString().contains('Method Not Allowed')) {
        print(
          '[PatientService] Primary endpoint not available, trying alternative...',
        );
        try {
          // Alternative: Get current user data from /me endpoint or similar
          // For now, return null and let the calling code use storage data
          return null;
        } catch (altError) {
          print('[PatientService] Alternative approach also failed: $altError');
          return null;
        }
      }
      print(st);
      return null;
    }
  }

  // Get monitoring classification only, do not save to DB
  Future<Map<String, dynamic>?> getMonitoringClassification(
    int gestationalAge,
    List<int> bpmData,
  ) async {
    try {
      final validBpm = bpmData.where((bpm) => bpm >= 50 && bpm <= 200).toList();
      final body = {'gestational_age': gestationalAge, 'bpm_data': validBpm};
      // Endpoint hanya untuk klasifikasi, misal /monitoring/classify
      final response = await _apiClient.dio.post(
        '/monitoring/classify',
        data: body,
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e, st) {
      print('[PatientService] Error getMonitoringClassification: $e');
      print(st);
      return null;
    }
  }

  final ApiClient _apiClient = ApiClient();

  // Get patients for doctor
  Future<List<Patient>> getPatients() async {
    print('[PatientService] Fetching patients...');
    try {
      final response = await _apiClient.dio.get('/monitoring/patients');
      print('[PatientService] Response: ${response.data}');
      List<Patient> patients = [];
      if (response.statusCode == 200) {
        if (response.data is List) {
          patients =
              (response.data as List)
                  .map((json) => Patient.fromJson(json))
                  .toList();
        } else if (response.data is Map && response.data['patients'] is List) {
          patients =
              (response.data['patients'] as List)
                  .map((json) => Patient.fromJson(json))
                  .toList();
        } else {
          print(
            '[PatientService] Response format tidak dikenali: ${response.data.runtimeType}',
          );
        }
        print('[PatientService] Parsed patients: $patients');
        return patients;
      } else {
        print('[PatientService] Unexpected response: ${response.statusCode}');
        return [];
      }
    } catch (e, st) {
      print('[PatientService] Error fetching patients: $e');
      print(st);
      return [];
    }
  }

  // Add patient by email
  Future<(bool, String?)> addPatient(String email) async {
    print('[PatientService] Adding patient with email: $email');
    // Always set JWT token from storage before request
    String? token = await StorageService.getToken();
    bool tokenExpired = false;
    if (token != null && token.isNotEmpty) {
      ApiClient().setAuthToken(token);
      print('[PatientService] JWT token set in ApiClient: $token');
      // Debug print JWT header & payload
      final parts = token.split('.');
      if (parts.length == 3) {
        try {
          final header = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[0])),
          );
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          print('[PatientService] JWT header: $header');
          print('[PatientService] JWT payload: $payload');
          // Print expiry info
          final payloadMap = json.decode(payload);
          if (payloadMap is Map && payloadMap.containsKey('exp')) {
            final exp = payloadMap['exp'];
            final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            print('[PatientService] JWT exp: $exp ($expDate)');
            print(
              '[PatientService] JWT is expired: ${DateTime.now().isAfter(expDate)}',
            );
            tokenExpired = DateTime.now().isAfter(expDate);
          }
        } catch (e) {
          print('[PatientService] Failed to decode JWT: $e');
        }
      }
    } else {
      print('[PatientService] No JWT token found in storage');
      tokenExpired = true;
    }

    // If token expired, auto re-login using saved credentials
    if (tokenExpired) {
      print('[PatientService] Token expired, attempting auto re-login...');
      final userDataJson = await StorageService.getUserData();
      if (userDataJson != null && userDataJson.isNotEmpty) {
        final userData = json.decode(userDataJson);
        final savedEmail = userData['email'] ?? '';
        final savedPassword = userData['password'] ?? '';
        if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
          final authService = AuthService();
          final result = await authService.login(
            email: savedEmail,
            password: savedPassword,
          );
          if (result.isSuccess && result.token != null) {
            token = result.token;
            ApiClient().setAuthToken(token!);
            print('[PatientService] Auto re-login success, new token set.');
          } else {
            print(
              '[PatientService] Auto re-login failed: ${result.errorMessage}',
            );
            return (false, 'Sesi login kadaluarsa, silakan login ulang.');
          }
        } else {
          print('[PatientService] No saved credentials for auto login.');
          return (false, 'Sesi login kadaluarsa, silakan login ulang.');
        }
      } else {
        print('[PatientService] No saved user data for auto login.');
        return (false, 'Sesi login kadaluarsa, silakan login ulang.');
      }
    }

    print(
      '[PatientService] Dio headers before request: ${_apiClient.dio.options.headers}',
    );
    try {
      final response = await _apiClient.dio.post(
        '/monitoring/patients/add',
        data: {
          'patient_email': email,
          'notes': 'Ditambahkan via aplikasi', // opsional, bisa diganti
        },
      );
      print(
        '[PatientService] Add response: ${response.statusCode} ${response.data}',
      );
      print(
        '[PatientService] Dio headers after request: ${_apiClient.dio.options.headers}',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (true, null);
      } else {
        String? errorMsg;
        if (response.data is Map && response.data['message'] != null) {
          errorMsg = response.data['message'].toString();
        } else {
          errorMsg = 'Gagal menambah pasien (status ${response.statusCode})';
        }
        return (false, errorMsg);
      }
    } catch (e, st) {
      print('[PatientService] Error adding patient: $e');
      print(st);
      return (false, e.toString());
    }
  }

  Future<Map<String, dynamic>?> submitMonitoring(
    int patientId,
    int gestationalAge,
    DateTime startTime,
    List<int> bpmData,
    String? notes, {
    int? doctorId,
  }) async {
    try {
      // Filter BPM agar hanya 50-200 (strict)
      final validBpm = bpmData.where((bpm) => bpm >= 50 && bpm <= 200).toList();
      if (validBpm.length != bpmData.length) {
        print(
          '[PatientService] WARNING: Some BPM values were filtered out. Original: $bpmData, Filtered: $validBpm',
        );
      }
      final body = {
        'patient_id': patientId,
        'gestational_age': gestationalAge,
        'start_time': startTime.toIso8601String(),
        'bpm_data': validBpm,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (doctorId != null) 'doctor_id': doctorId,
      };
      print('[PatientService] Submit body: $body');
      final response = await _apiClient.dio.post(
        '/monitoring/submit',
        data: body,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[PatientService] Error submit monitoring: $e');
      return null;
    }
  }
}
