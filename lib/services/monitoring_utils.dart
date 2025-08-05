// =============================================================================
// Monitoring Utility & Service Functions
// =============================================================================

import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/services/patient_service.dart';
import 'package:dopply_app/services/monitoring_service.dart'
    show MonitoringState;

class MonitoringUtils {
  static Future<_MonitoringResult?> submitMonitoringSession(
    MonitoringState state,
    String? userRole,
    Patient? currentPatient,
    List<Patient> patients,
    String? selectedPatientId,
    void Function(String error) onError, {
    List<int>? customBpmData,
  }) async {
    final bpmDataRaw =
        customBpmData ?? state.realTimeData.map((point) => point.bpm).toList();
    debugPrint('[MonitoringUtils] submitMonitoringSession called');
    debugPrint('customBpmData: $customBpmData');
    debugPrint('bpmDataRaw: $bpmDataRaw');
    if (bpmDataRaw.isEmpty) {
      debugPrint('[MonitoringUtils] bpmDataRaw is empty, request not sent');
      return null;
    }
    try {
      final bpmDataFiltered =
          bpmDataRaw.where((bpm) => bpm >= 50 && bpm <= 200).toList();
      int patientId;
      int gestationalAge;
      Patient? patient;
      if (userRole == 'patient' && currentPatient != null) {
        patient = currentPatient;
      } else {
        patient = patients.firstWhere(
          (p) => p.id.toString() == selectedPatientId,
          orElse: () => patients.first,
        );
      }
      patientId = patient.id;
      gestationalAge = patient.gestationalAge ?? 0;
      if (gestationalAge < 20 || gestationalAge > 42) {
        onError('Usia kehamilan harus antara 20 dan 42 minggu.');
        debugPrint('[MonitoringUtils] Invalid gestationalAge: $gestationalAge');
        return null;
      }
      final apiClient = ApiClient();
      debugPrint('[MonitoringUtils] Sending POST /monitoring/classify');
      debugPrint('patient_id: $patientId');
      debugPrint('gestational_age: $gestationalAge');
      debugPrint(
        'timestamp: ' +
            ((customBpmData != null || state.realTimeData.isEmpty)
                ? DateTime.now().toIso8601String()
                : state.realTimeData.first.timestamp.toIso8601String()),
      );
      debugPrint('bpm_data: $bpmDataFiltered');
      final dioResponse = await apiClient.dio.post(
        '/monitoring/classify',
        data: {
          'patient_id': patientId,
          'gestational_age': gestationalAge,
          'timestamp':
              (customBpmData != null || state.realTimeData.isEmpty)
                  ? DateTime.now().toIso8601String()
                  : state.realTimeData.first.timestamp.toIso8601String(),
          'bpm_data': bpmDataFiltered,
        },
      );
      debugPrint(
        '[MonitoringUtils] Response status: ${dioResponse.statusCode}',
      );
      debugPrint('[MonitoringUtils] Response data: ${dioResponse.data}');
      final response = dioResponse.data;
      if (response != null) {
        final classification = response['classification']?.toString();
        final avgBpm = response['average_bpm']?.toString();
        return _MonitoringResult(
          monitoringResult:
              classification != null && classification.isNotEmpty
                  ? 'Klasifikasi: $classification\nRata-rata BPM: ${avgBpm ?? '-'}'
                  : 'Hasil monitoring tersedia.',
          monitoringResultId: response['id'],
        );
      }
    } catch (e) {
      debugPrint('[MonitoringUtils] ERROR: $e');
      onError('Gagal submit monitoring: $e');
    }
    return null;
  }

  static Future<void> shareMonitoringResult(
    BuildContext context,
    int? monitoringResultId,
    void Function(String msg) showMsg,
  ) async {
    if (monitoringResultId == null) {
      showMsg('Hasil monitoring belum tersedia untuk dibagikan.');
      return;
    }
    List<Patient> doctors = [];
    try {
      doctors = await fetchDoctorsForPatient();
    } catch (e) {
      showMsg('Gagal mengambil daftar dokter: $e');
      return;
    }
    if (doctors.isEmpty) {
      showMsg('Tidak ada dokter yang terhubung dengan Anda.');
      return;
    }
    int? selectedDoctorId = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Dokter Tujuan'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return ListTile(
                  title: Text(doctor.name),
                  subtitle: Text(doctor.email),
                  onTap: () {
                    Navigator.of(context).pop(doctor.id);
                  },
                );
              },
            ),
          ),
        );
      },
    );
    if (selectedDoctorId == null) return;
    try {
      final dioResponse = await ApiClient().dio.post(
        '/monitoring/share',
        data: {'record_id': monitoringResultId, 'doctor_id': selectedDoctorId},
      );
      final response = dioResponse.data;
      if (response != null && response['success'] == true) {
        showMsg('Hasil monitoring berhasil dibagikan ke dokter.');
      } else {
        showMsg(
          'Gagal membagikan hasil monitoring: ${response?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      showMsg('Gagal membagikan hasil monitoring: $e');
    }
  }

  static Future<int?> saveMonitoringResult(
    BuildContext context,
    MonitoringState state,
    String? userRole,
    Patient? currentPatient,
    List<Patient> patients,
    String? selectedPatientId,
    String notes,
    T Function<T>(ProviderListenable<T> provider) read,
    void Function(String msg) showMsg, {
    List<int>? customBpmData,
  }) async {
    int patientId;
    int gestationalAge;
    Patient? patient;
    if (userRole == 'patient' && currentPatient != null) {
      patient = currentPatient;
    } else {
      patient = patients.firstWhere(
        (p) => p.id.toString() == selectedPatientId,
        orElse: () => patients.first,
      );
    }
    patientId = patient.id;
    gestationalAge = patient.gestationalAge ?? 0;
    final bpmDataRaw =
        customBpmData ?? state.realTimeData.map((point) => point.bpm).toList();
    if (bpmDataRaw.isEmpty) {
      showMsg('Data monitoring tidak tersedia.');
      return null;
    }
    try {
      final patientService = read(patientServiceProvider);
      final bpmDataFiltered =
          bpmDataRaw.where((bpm) => bpm >= 50 && bpm <= 200).toList();
      final response = await patientService.submitMonitoring(
        patientId,
        gestationalAge,
        (customBpmData != null || state.realTimeData.isEmpty)
            ? DateTime.now()
            : state.realTimeData.first.timestamp,
        bpmDataFiltered,
        notes,
      );
      int? monitoringResultId;
      if (response != null) {
        if (response['id'] != null) {
          monitoringResultId = int.tryParse(response['id'].toString());
        }
        // Jika ada message sukses dari backend, tampilkan
        if (response['message'] != null &&
            response['message'].toString().toLowerCase().contains('berhasil')) {
          showMsg(response['message']);
        } else {
          showMsg('Hasil monitoring berhasil disimpan secara pribadi.');
        }
        return monitoringResultId;
      } else {
        showMsg(
          'Gagal menyimpan hasil monitoring: ${response?['message'] ?? 'Unknown error'}',
        );
        return null;
      }
    } catch (e) {
      showMsg('Gagal menyimpan hasil monitoring: $e');
      return null;
    }
  }

  // Existing utility functions
  static Future<List<Patient>> fetchDoctorsForPatient() async {
    // ...existing code...
    return [];
  }

  static String classifyBpm(int bpm) {
    // ...existing code...
    return '';
  }
}

class _MonitoringResult {
  final String? monitoringResult;
  final int? monitoringResultId;
  _MonitoringResult({this.monitoringResult, this.monitoringResultId});
}
