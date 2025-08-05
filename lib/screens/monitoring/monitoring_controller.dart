import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/models/monitoring.dart';
import 'package:dopply_app/services/patient_service.dart';
import 'package:dopply_app/services/ble_service.dart';
import 'package:dopply_app/services/monitoring_utils.dart';
import 'package:dopply_app/core/dialog_snackbar_utils.dart';
import 'package:dopply_app/services/monitoring_service.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/core/api_client.dart';
import 'dart:convert';
// Provider untuk BLE dan monitoring state
import 'package:dopply_app/screens/monitoring/monitoring_screen.dart'
    show fetalDopplerBLEServiceProvider;
import 'package:dopply_app/services/monitoring_service.dart'
    show currentMonitoringProvider;

class MonitoringController {
  static Future<void> setApiTokenFromStorage() async {
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      ApiClient().setAuthToken(token);
      debugPrint('[MonitoringController] JWT token set to ApiClient');
    } else {
      debugPrint('[MonitoringController] No JWT token found in storage');
    }
  }

  static Future<void> fetchUserRole({
    required void Function(void Function()) setState,
    required void Function(String?) setUserRole,
    required void Function(Patient?) setCurrentPatient,
    required Future<void> Function() fetchPatients,
  }) async {
    final role = await StorageService.getRole();
    setState(() {
      setUserRole(role);
    });
    debugPrint('[MonitoringController] User role: \u001b[32m$role\u001b[0m');

    if (role == 'patient') {
      final userJson = await StorageService.getUserData();
      if (userJson != null && userJson.isNotEmpty) {
        final userMap = jsonDecode(userJson);
        debugPrint('[MonitoringController] JWT user data: $userMap');
        final patientId = userMap['patient_id'] ?? userMap['id'];
        setState(() {
          setCurrentPatient(
            Patient(
              id: patientId,
              name: userMap['name'] ?? '',
              email: userMap['email'] ?? '',
              gestationalAge: userMap['gestational_age'],
              hpht: null,
            ),
          );
        });
      }
    } else {
      await fetchPatients();
    }
  }

  static Future<void> fetchPatients({
    required BuildContext context,
    required WidgetRef ref,
    required void Function(void Function()) setState,
    required void Function(List<Patient>) setPatients,
    required void Function(String?) setSelectedPatientId,
    required void Function(bool) setIsLoading,
  }) async {
    setState(() {
      setIsLoading(true);
    });
    try {
      final patientService = ref.read(patientServiceProvider);
      final patients = await patientService.getPatients();
      setState(() {
        setPatients(patients);
        if (patients.isNotEmpty) {
          setSelectedPatientId(patients.first.id.toString());
        } else {
          setSelectedPatientId(null);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data pasien: $e')),
      );
    } finally {
      setState(() {
        setIsLoading(false);
      });
    }
  }

  static Future<void> connectEsp32({
    required WidgetRef ref,
    required Future<void> Function(BluetoothDevice) connectToDevice,
  }) async {
    final bleService = ref.read(fetalDopplerBLEServiceProvider.notifier);
    await bleService.startScan();
    bleService.deviceListStream.listen((devices) async {
      BluetoothDevice? esp32Device;
      try {
        esp32Device = devices.firstWhere(
          (d) => d.name.startsWith('Dopply-FetalMonitor'),
        );
      } catch (_) {
        esp32Device = null;
      }
      if (esp32Device != null) {
        await bleService.stopScan();
        await connectToDevice(esp32Device);
      }
    });
  }

  static Future<void> connectToDevice({
    required BuildContext context,
    required WidgetRef ref,
    required BluetoothDevice device,
  }) async {
    final bleService = ref.read(fetalDopplerBLEServiceProvider.notifier);
    final connected = await bleService.connectToDevice(device);
    if (connected) {
      ref.read(currentMonitoringProvider.notifier).setConnected(true);
      SnackbarUtils.showSnackbar(context, 'Terhubung ke ${device.name}');
    } else {
      ref
          .read(currentMonitoringProvider.notifier)
          .setError('Gagal menghubungkan ke perangkat BLE');
    }
  }

  static Future<void> startMonitoring({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      final bleService = ref.read(fetalDopplerBLEServiceProvider.notifier);
      ref.read(currentMonitoringProvider.notifier).setMonitoring(true);
      ref.read(currentMonitoringProvider.notifier).clearRealTimeData();
      await bleService.startMonitoring();
      bleService.heartRateStream.listen((data) {
        final dataPoint = BpmDataPoint(
          timestamp: data.timestamp,
          bpm: data.bpm,
        );
        ref.read(currentMonitoringProvider.notifier).addRealTimeData(dataPoint);
      });
      SnackbarUtils.showSnackbar(context, 'Monitoring dimulai');
    } catch (e) {
      ref
          .read(currentMonitoringProvider.notifier)
          .setError('Gagal memulai monitoring: $e');
    }
  }

  static Future<void> stopMonitoring({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      ref.read(currentMonitoringProvider.notifier).setMonitoring(false);
      SnackbarUtils.showSnackbar(context, 'Monitoring dihentikan');
    } catch (e) {
      ref
          .read(currentMonitoringProvider.notifier)
          .setError('Gagal menghentikan monitoring: $e');
    }
  }

  static Future<void> submitMonitoringSession({
    required BuildContext context,
    required WidgetRef ref,
    required String? userRole,
    required Patient? currentPatient,
    required List<Patient> patients,
    required String? selectedPatientId,
    required void Function(void Function()) setState,
    required void Function(String?) setMonitoringResult,
    required void Function(int?) setMonitoringResultId,
    List<int>? customBpmData,
  }) async {
    final state = ref.read(currentMonitoringProvider);
    final bpmDataToUse =
        customBpmData ?? state.realTimeData.map((point) => point.bpm).toList();
    if (bpmDataToUse.isEmpty) return;
    final result = await MonitoringUtils.submitMonitoringSession(
      state,
      userRole,
      currentPatient,
      patients,
      selectedPatientId,
      (error) => ref.read(currentMonitoringProvider.notifier).setError(error),
      customBpmData: customBpmData,
    );
    if (result != null) {
      setState(() {
        setMonitoringResult(result.monitoringResult);
        setMonitoringResultId(result.monitoringResultId);
      });
      SnackbarUtils.showSnackbar(
        context,
        result.monitoringResult ?? 'Hasil monitoring tersedia.',
      );
    }
  }

  static Future<void> disconnect({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      final bleService = ref.read(fetalDopplerBLEServiceProvider.notifier);
      await bleService.disconnect();
      ref.read(currentMonitoringProvider.notifier).setConnected(false);
      ref.read(currentMonitoringProvider.notifier).setMonitoring(false);
      ref.read(currentMonitoringProvider.notifier).clearRealTimeData();
      SnackbarUtils.showSnackbar(context, 'Perangkat diputuskan');
    } catch (e) {
      ref
          .read(currentMonitoringProvider.notifier)
          .setError('Gagal memutuskan koneksi: $e');
    }
  }

  static Future<void> shareMonitoringResult({
    required BuildContext context,
    required int? monitoringResultId,
  }) async {
    await MonitoringUtils.shareMonitoringResult(
      context,
      monitoringResultId,
      (msg) => SnackbarUtils.showSnackbar(context, msg),
    );
  }

  static Future<void> saveMonitoringResult({
    required BuildContext context,
    required WidgetRef ref,
    required String? userRole,
    required Patient? currentPatient,
    required List<Patient> patients,
    required String? selectedPatientId,
    required String notes,
    List<int>? customBpmData,
    void Function(int id)? setMonitoringResultId,
  }) async {
    final state = ref.read(currentMonitoringProvider);
    final bpmDataToUse =
        customBpmData ?? state.realTimeData.map((point) => point.bpm).toList();
    final resultId = await MonitoringUtils.saveMonitoringResult(
      context,
      state,
      userRole,
      currentPatient,
      patients,
      selectedPatientId,
      notes,
      ref.read,
      (msg) => SnackbarUtils.showSnackbar(context, msg),
      customBpmData: customBpmData,
    );
    if (setMonitoringResultId != null && resultId != null) {
      setMonitoringResultId(resultId);
    }
  }
}
