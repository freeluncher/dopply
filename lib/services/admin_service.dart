import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:dopply_app/core/storage.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

class AdminService {
  // Get JWT token from secure storage
  Future<String?> _getToken() async {
    return await StorageService.getToken();
  }

  // Get list of unverified doctors
  Future<List<DoctorForVerification>> getUnverifiedDoctors() async {
    try {
      // Get all doctors first, then filter for unverified ones
      final allDoctors = await getAllDoctors();
      return allDoctors.where((doctor) => !doctor.isVerified).toList();
    } catch (e) {
      print('Error fetching unverified doctors: $e');
      throw Exception('Failed to fetch unverified doctors: $e');
    }
  }

  // Verify a doctor
  Future<bool> verifyDoctor(int doctorId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/monitoring/admin/verify-doctor'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'doctor_id': doctorId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Admin access required.');
      } else if (response.statusCode == 404) {
        throw Exception('Doctor not found');
      } else {
        throw Exception('Failed to verify doctor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error verifying doctor: $e');
      return false;
    }
  }

  // Get all doctors (verified and unverified) for admin overview
  Future<List<DoctorForVerification>> getAllDoctors() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/all-doctors'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        List<dynamic> doctorsList;
        if (jsonResponse is Map && jsonResponse.containsKey('doctors')) {
          doctorsList = jsonResponse['doctors'] as List;
        } else if (jsonResponse is List) {
          doctorsList = jsonResponse;
        } else {
          doctorsList = [];
        }

        return doctorsList
            .map(
              (doctor) => DoctorForVerification.fromJson(
                doctor as Map<String, dynamic>,
              ),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Admin access required.');
      } else {
        throw Exception('Failed to fetch doctors: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching doctors: $e');
      throw Exception('Failed to fetch doctors: $e');
    }
  }
}

// Model for doctor verification
class DoctorForVerification {
  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? specialization;
  final String? licenseNumber;
  final bool isVerified;
  final DateTime createdAt;
  final String? photoUrl;

  const DoctorForVerification({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.specialization,
    this.licenseNumber,
    required this.isVerified,
    required this.createdAt,
    this.photoUrl,
  });

  factory DoctorForVerification.fromJson(Map<String, dynamic> json) {
    return DoctorForVerification(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      specialization: json['specialization'],
      licenseNumber: json['license_number'],
      isVerified: json['is_verified'] ?? false,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'specialization': specialization,
      'license_number': licenseNumber,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
    };
  }

  // Helper methods
  String get statusText => isVerified ? 'Terverifikasi' : 'Menunggu Verifikasi';
  String get registrationTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
