// =============================================================================
// Monitoring Service - Simplified BLE and Data Management
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:dopply_app/models/monitoring.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:http/http.dart' as http;
import 'package:dopply_app/core/api_client.dart';

// Monitoring service provider
final monitoringServiceProvider = Provider<MonitoringService>((ref) {
  return MonitoringService();
});

// Current monitoring session provider
final currentMonitoringProvider =
    StateNotifierProvider<MonitoringNotifier, MonitoringState>((ref) {
      return MonitoringNotifier();
    });

// Monitoring history provider
final monitoringHistoryProvider = FutureProvider<List<MonitoringResult>>((
  ref,
) async {
  final service = ref.read(monitoringServiceProvider);
  return await service.fetchMonitoringHistoryFromBackend();
});

class MonitoringState {
  final bool isConnected;
  final bool isMonitoring;
  final MonitoringResult? currentSession;
  final List<BpmDataPoint> realTimeData;
  final String? error;

  const MonitoringState({
    this.isConnected = false,
    this.isMonitoring = false,
    this.currentSession,
    this.realTimeData = const [],
    this.error,
  });

  MonitoringState copyWith({
    bool? isConnected,
    bool? isMonitoring,
    MonitoringResult? currentSession,
    List<BpmDataPoint>? realTimeData,
    String? error,
  }) {
    return MonitoringState(
      isConnected: isConnected ?? this.isConnected,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      currentSession: currentSession ?? this.currentSession,
      realTimeData: realTimeData ?? this.realTimeData,
      error: error,
    );
  }
}

class MonitoringNotifier extends StateNotifier<MonitoringState> {
  MonitoringNotifier() : super(const MonitoringState());

  void setConnected(bool connected) {
    state = state.copyWith(isConnected: connected, error: null);
  }

  void setMonitoring(bool monitoring) {
    state = state.copyWith(isMonitoring: monitoring, error: null);
  }

  void setCurrentSession(MonitoringResult session) {
    state = state.copyWith(currentSession: session, error: null);
  }

  void addRealTimeData(BpmDataPoint dataPoint) {
    final newData = [...state.realTimeData, dataPoint];
    // Keep only last 100 data points for performance
    final limitedData =
        newData.length > 100 ? newData.sublist(newData.length - 100) : newData;
    state = state.copyWith(realTimeData: limitedData, error: null);
  }

  void clearRealTimeData() {
    state = state.copyWith(realTimeData: [], error: null);
  }

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class MonitoringService {
  // Ambil riwayat monitoring dari backend
  Future<List<MonitoringResult>> fetchMonitoringHistoryFromBackend({
    int? patientId,
    int skip = 0,
    int limit = 20,
  }) async {
    debugPrint('[MonitoringService] fetchMonitoringHistoryFromBackend called');
    final startTime = DateTime.now();
    try {
      // Ambil baseUrl dari ApiConfig, hapus /api/v1 jika hanya butuh domain:port
      final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
      debugPrint('[MonitoringService] Fetching token and user from storage...');
      final token = await StorageService.getToken();
      debugPrint('[MonitoringService] JWT token: $token');
      final userJson = await StorageService.getUserData();
      debugPrint('[MonitoringService] Raw user from storage: $userJson');
      if (userJson != null) {
        try {
          final userMap = jsonDecode(userJson);
          debugPrint('[MonitoringService] Decoded user map: $userMap');
        } catch (e) {
          debugPrint('[MonitoringService] Error decoding user: $e');
        }
      }
      // Build query params
      final queryParams = <String, dynamic>{'skip': skip, 'limit': limit};
      if (patientId != null) {
        queryParams['patient_id'] = patientId;
      }
      final uri = Uri.parse(
        '$baseUrl/api/v1/monitoring/history',
      ).replace(queryParameters: queryParams);
      debugPrint(
        '[MonitoringService] Requesting: [38;5;10m${uri.toString()}[0m',
      );
      debugPrint('[MonitoringService] Preparing http request...');
      try {
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
        final endTime = DateTime.now();
        debugPrint(
          '[MonitoringService] http request finished in ${endTime.difference(startTime).inMilliseconds} ms',
        );
        debugPrint(
          '[MonitoringService] Response statusCode: ${response.statusCode}',
        );
        debugPrint('[MonitoringService] Response body: ${response.body}');
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          debugPrint('[MonitoringService] Decoded response: $decoded');
          List<MonitoringResult> results = [];
          if (decoded is List) {
            debugPrint('[MonitoringService] Parsing as List');
            for (var item in decoded) {
              try {
                final result = MonitoringResult.fromJson(item);
                results.add(result);
              } catch (e) {
                debugPrint('[MonitoringService] Error parsing item: $e');
              }
            }
          } else if (decoded is Map && decoded['data'] is List) {
            debugPrint('[MonitoringService] Parsing as Map[data]');
            for (var item in decoded['data']) {
              try {
                final result = MonitoringResult.fromJson(item);
                results.add(result);
              } catch (e) {
                debugPrint('[MonitoringService] Error parsing item: $e');
              }
            }
          } else {
            debugPrint(
              '[MonitoringService] Unexpected response type: ${decoded.runtimeType}',
            );
            debugPrint(
              '[MonitoringService] Unexpected response content: $decoded',
            );
          }
          debugPrint(
            '[MonitoringService] Parsed results count: ${results.length}',
          );
          return results;
        } else {
          debugPrint('[MonitoringService] No valid data found in response');
          return [];
        }
      } catch (e) {
        debugPrint('[MonitoringService] http error: $e');
        return [];
      }
    } catch (e) {
      print('Error fetching monitoring history from backend: $e');
      return [];
    }
  }

  static const String _historyKey = 'monitoring_history';
  static const String _deviceNamePrefix = 'Dopply_';

  // BLE connection
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _dataSubscription;

  // Get monitoring history from storage
  Future<List<MonitoringResult>> getMonitoringHistory() async {
    try {
      final historyJson = await StorageService.getMonitoringHistory();
      if (historyJson != null) {
        final historyData = jsonDecode(historyJson);
        if (historyData is List) {
          return historyData
              .map((item) => MonitoringResult.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error loading monitoring history: $e');
      return [];
    }
  }

  // Save monitoring result to storage
  Future<void> saveMonitoringResult(MonitoringResult result) async {
    try {
      final history = await getMonitoringHistory();
      history.insert(0, result); // Add to beginning

      // Keep only last 50 monitoring sessions
      final limitedHistory = history.take(50).toList();

      final historyJson = jsonEncode(
        limitedHistory.map((r) => r.toJson()).toList(),
      );
      await StorageService.saveMonitoringHistory(historyJson);
      print('Monitoring result saved: ${result.id}');
    } catch (e) {
      print('Error saving monitoring result: $e');
    }
  }

  // Scan for Dopply devices
  Future<List<BluetoothDevice>> scanForDopplyDevices() async {
    try {
      final foundDevices = <BluetoothDevice>[];

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Listen for scan results
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          final deviceName = device.platformName;

          if (deviceName.startsWith(_deviceNamePrefix) &&
              !foundDevices.any((d) => d.remoteId == device.remoteId)) {
            foundDevices.add(device);
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();

      return foundDevices;
    } catch (e) {
      print('Error scanning for devices: $e');
      return [];
    }
  }

  // Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }
    } catch (e) {
      print('Error disconnecting device: $e');
    }
  }

  // Start monitoring
  Future<bool> startMonitoring(Function(BpmDataPoint) onDataReceived) async {
    if (_connectedDevice == null) return false;

    try {
      final services = await _connectedDevice!.discoverServices();

      // Find the monitoring service and characteristic
      // This is a simplified version - in reality you'd need specific UUIDs
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);

            _dataSubscription = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                // Parse BLE data - this is simplified
                final bpm = _parseBpmData(value);
                final dataPoint = BpmDataPoint(
                  timestamp: DateTime.now(),
                  bpm: bpm,
                );
                onDataReceived(dataPoint);
              }
            });

            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error starting monitoring: $e');
      return false;
    }
  }

  // Stop monitoring
  Future<void> stopMonitoring() async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;
  }

  // Parse BPM data from BLE bytes (simplified)
  int _parseBpmData(List<int> data) {
    // This is a simplified parser
    // In reality, you'd need to implement the actual protocol
    if (data.length >= 2) {
      return (data[0] << 8) | data[1];
    }
    return 0;
  }

  // Generate mock data for testing
  static List<BpmDataPoint> generateMockData() {
    final now = DateTime.now();
    final data = <BpmDataPoint>[];

    for (int i = 0; i < 60; i++) {
      final timestamp = now.subtract(Duration(seconds: 60 - i));
      final bpm = 120 + (10 * (0.5 - (i % 20) / 20.0)).round();
      data.add(BpmDataPoint(timestamp: timestamp, bpm: bpm));
    }

    return data;
  }
}
