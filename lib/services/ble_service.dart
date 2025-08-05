// =============================================================================
// Fetal Doppler BLE Service
//
// Specialized BLE service for connecting to ESP32-based fetal doppler devices
// Handles fetal heart rate monitoring with gestational age consideration
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Fetal Doppler BLE Configuration
class FetalDopplerConfig {
  static const String deviceNamePrefix = "Dopply-FetalMonitor";
  static const String serviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUUID =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String txCharacteristicUUID =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
  static const Duration scanTimeout = Duration(seconds: 15);
  static const Duration connectionTimeout = Duration(seconds: 20);
}

// BLE Connection States
enum BLEConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
  monitoring,
}

// Fetal Heart Rate Data Model
class FetalHeartRateData {
  final int bpm;
  final DateTime timestamp;
  final double? signalQuality;
  final FetalBPMClassification classification;

  const FetalHeartRateData({
    required this.bpm,
    required this.timestamp,
    this.signalQuality,
    required this.classification,
  });

  factory FetalHeartRateData.fromBytes(Uint8List data, int gestationalAge) {
    // Parse ESP32 fetal doppler data format
    // Expected format: [BPM_HIGH, BPM_LOW, QUALITY, ...]
    if (data.length >= 3) {
      // Binary format (preferred)
      final bpm = (data[0] << 8) | data[1];
      final quality = data[2] / 100.0; // Signal quality percentage
      final classification = FetalBPMClassifier.classify(bpm, gestationalAge);

      return FetalHeartRateData(
        bpm: bpm,
        timestamp: DateTime.now(),
        signalQuality: quality,
        classification: classification,
      );
    } else {
      throw FormatException(
        'Invalid fetal doppler data format - insufficient data',
      );
    }
  }

  // Factory for string format (ESP32 compatibility)
  factory FetalHeartRateData.fromString(String data, int gestationalAge) {
    // ESP32 sends format like "137 (Normal)" or "120 (Bradikardia)"
    // Extract the BPM number from the string
    final bpmMatch = RegExp(r'(\d+)').firstMatch(data.trim());
    final bpm = bpmMatch != null ? int.parse(bpmMatch.group(1)!) : 0;

    // Use ESP32 classification if available, otherwise calculate
    FetalBPMClassification classification;
    final lowerData = data.toLowerCase();

    if (lowerData.contains('bradikardia') ||
        lowerData.contains('bradycardia')) {
      classification = FetalBPMClassification.bradycardia;
    } else if (lowerData.contains('takikardia') ||
        lowerData.contains('tachycardia')) {
      classification = FetalBPMClassification.tachycardia;
    } else if (lowerData.contains('normal')) {
      classification = FetalBPMClassification.normal;
    } else {
      // Fallback to calculated classification
      classification = FetalBPMClassifier.classify(bpm, gestationalAge);
    }

    // Estimate signal quality based on BPM value and classification
    // Support extended BPM range 0-500 as per backend integration guide
    double signalQuality = 0.0;
    if (bpm > 0) {
      if (classification == FetalBPMClassification.normal) {
        signalQuality = 0.90; // High quality for normal readings
      } else if (bpm >= 10 && bpm <= 400) {
        signalQuality =
            0.75; // Moderate quality for abnormal but reasonable values
      } else if (bpm >= 1 && bpm <= 500) {
        signalQuality = 0.50; // Lower quality for extreme values
      } else {
        signalQuality = 0.25; // Very low quality for out-of-range values
      }
    }

    return FetalHeartRateData(
      bpm: bpm,
      timestamp: DateTime.now(),
      signalQuality: signalQuality,
      classification: classification,
    );
  }

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'timestamp': timestamp.toIso8601String(),
    'signal_quality': signalQuality,
    'classification': classification.name,
  };
}

// Fetal BPM Classification
enum FetalBPMClassification { normal, bradycardia, tachycardia, irregular }

// Fetal BPM Classifier
class FetalBPMClassifier {
  static FetalBPMClassification classify(int bpm, int gestationalAge) {
    // Support BPM range 0-500 as per backend integration guide
    // Backend now accepts any BPM value in this range

    // Handle extreme low values (0-50 BPM)
    if (bpm <= 50) {
      return FetalBPMClassification.bradycardia; // Severe bradycardia
    }

    // Handle extreme high values (250+ BPM)
    if (bpm >= 250) {
      return FetalBPMClassification.tachycardia; // Severe tachycardia
    }

    // Fetal heart rate ranges based on gestational age
    if (gestationalAge < 20) {
      // Early pregnancy: 120-180 BPM
      if (bpm < 120) return FetalBPMClassification.bradycardia;
      if (bpm > 180) return FetalBPMClassification.tachycardia;
    } else if (gestationalAge < 32) {
      // Mid pregnancy: 115-170 BPM
      if (bpm < 115) return FetalBPMClassification.bradycardia;
      if (bpm > 170) return FetalBPMClassification.tachycardia;
    } else {
      // Late pregnancy: 110-160 BPM
      if (bpm < 110) return FetalBPMClassification.bradycardia;
      if (bpm > 160) return FetalBPMClassification.tachycardia;
    }
    return FetalBPMClassification.normal;
  }

  static String getClassificationDescription(
    FetalBPMClassification classification,
  ) {
    switch (classification) {
      case FetalBPMClassification.normal:
        return 'Normal fetal heart rate';
      case FetalBPMClassification.bradycardia:
        return 'Fetal bradycardia - slow heart rate';
      case FetalBPMClassification.tachycardia:
        return 'Fetal tachycardia - fast heart rate';
      case FetalBPMClassification.irregular:
        return 'Irregular fetal heart rhythm';
    }
  }
}

// Fetal Doppler BLE Service
class FetalDopplerBLEService extends StateNotifier<BLEConnectionState> {
  FetalDopplerBLEService() : super(BLEConnectionState.disconnected);

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;

  // Stream controllers
  final _heartRateController = StreamController<FetalHeartRateData>.broadcast();
  final _deviceListController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters for streams
  Stream<FetalHeartRateData> get heartRateStream => _heartRateController.stream;
  Stream<List<BluetoothDevice>> get deviceListStream =>
      _deviceListController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Current gestational age (set before monitoring)
  int _gestationalAge = 20;

  // Simulation properties
  Timer? _simulationTimer;
  bool _isSimulatingData = false;

  void setGestationalAge(int weeks) {
    _gestationalAge = weeks;
  }

  // Check and handle common Android BLE issues
  Future<bool> checkBluetoothHealth() async {
    try {
      print('[BLE] Checking Bluetooth health...');

      // Check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      print('[BLE] Adapter state: $adapterState');

      if (adapterState != BluetoothAdapterState.on) {
        _errorController.add(
          'Bluetooth is not enabled. Please enable Bluetooth.',
        );
        return false;
      }

      // Check for any connected devices that might interfere
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      print('[BLE] Currently connected devices: ${connectedDevices.length}');

      for (var device in connectedDevices) {
        print(
          '[BLE] Connected device: ${device.platformName} (${device.remoteId})',
        );
      }

      // Stop any ongoing scans
      if (await FlutterBluePlus.isScanning.first) {
        print('[BLE] Stopping ongoing scan...');
        await FlutterBluePlus.stopScan();
        await Future.delayed(Duration(milliseconds: 1000));
      }

      return true;
    } catch (e) {
      print('[BLE] Bluetooth health check failed: ${e.toString()}');
      _errorController.add('Bluetooth health check failed: ${e.toString()}');
      return false;
    }
  }

  // Reset BLE stack (Android workaround for status=133)
  Future<void> resetBluetoothConnection() async {
    print('[BLE] Resetting Bluetooth connection...');

    try {
      // Disconnect all current connections
      await disconnect();

      // Wait for BLE stack to settle
      await Future.delayed(Duration(seconds: 2));

      // Stop any scans
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
        await Future.delayed(Duration(milliseconds: 1000));
      }

      print('[BLE] Bluetooth connection reset completed');
      _errorController.add(
        'Bluetooth connection reset. Please try connecting again.',
      );
    } catch (e) {
      print('[BLE] Error during Bluetooth reset: ${e.toString()}');
      _errorController.add('Bluetooth reset failed: ${e.toString()}');
    }
  }

  // Scan for fetal doppler devices
  Future<void> startScan() async {
    try {
      print('[BLE] Starting BLE scan for fetal doppler devices...');
      state = BLEConnectionState.scanning;

      // Check Bluetooth health first
      if (!await checkBluetoothHealth()) {
        state = BLEConnectionState.error;
        return;
      }

      final List<BluetoothDevice> devices = [];

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        devices.clear();
        print('[BLE] Scan results: ${results.length} devices found');

        for (var result in results) {
          final deviceName = result.device.platformName;
          final deviceId = result.device.remoteId.toString();
          final rssi = result.rssi;

          print(
            '[BLE] Found device: "$deviceName" (ID: $deviceId, RSSI: $rssi)',
          );

          // Be very permissive - add any device with a name for debugging
          if (deviceName.isNotEmpty) {
            // Check if it matches our ESP32
            if (deviceName.startsWith(FetalDopplerConfig.deviceNamePrefix) ||
                deviceName.contains("Dopply") ||
                deviceName.contains("FetalMonitor") ||
                deviceName.toLowerCase().contains("dopply") ||
                deviceName.toLowerCase().contains("fetal")) {
              print('[BLE] ✅ Adding ESP32 compatible device: "$deviceName"');
              devices.add(result.device);
            } else {
              print('[BLE] ❌ Skipping non-ESP32 device: "$deviceName"');
            }
          } else {
            print('[BLE] ❌ Skipping unnamed device (ID: $deviceId)');
          }
        }

        print('[BLE] Compatible devices found: ${devices.length}');
        _deviceListController.add(devices);
      });

      // Start scan with more permissive settings
      await FlutterBluePlus.startScan(
        timeout: FetalDopplerConfig.scanTimeout,
        androidUsesFineLocation: false, // Try without fine location requirement
      );

      print(
        '[BLE] Scan started, timeout: ${FetalDopplerConfig.scanTimeout.inSeconds}s',
      );

      // Add a delayed check for debugging
      Future.delayed(Duration(seconds: 3), () {
        print('[BLE] 3 seconds elapsed - checking scan progress...');
      });

      Future.delayed(Duration(seconds: 8), () {
        print(
          '[BLE] 8 seconds elapsed - scanning should be finding devices...',
        );
        if (devices.isEmpty) {
          print('[BLE] ⚠️ Still no devices found - likely permissions issue');
        }
      });
    } catch (e) {
      print('[BLE] Scan failed: ${e.toString()}');
      state = BLEConnectionState.error;
      _errorController.add('Scan failed: ${e.toString()}');
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    print('[BLE] Stopping BLE scan...');
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    if (state == BLEConnectionState.scanning) {
      state = BLEConnectionState.disconnected;
    }
    print('[BLE] Scan stopped');
  }

  // Connect to fetal doppler device with Android BLE error handling
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print(
        '[BLE] Connecting to device: ${device.platformName} (${device.remoteId})',
      );
      state = BLEConnectionState.connecting;

      // Stop scanning first to avoid conflicts
      if (await FlutterBluePlus.isScanning.first) {
        print('[BLE] Stopping scan before connection attempt...');
        await FlutterBluePlus.stopScan();
        await Future.delayed(
          Duration(milliseconds: 1000),
        ); // Wait for scan to fully stop
      }

      // Check if device is already connected
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      if (connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        print('[BLE] Device already connected, using existing connection');
        _connectedDevice = device;
      } else {
        // Implement retry logic for Android BLE status=133 error
        bool connected = false;
        int maxRetries = 3;

        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            print('[BLE] Connection attempt $attempt/$maxRetries...');

            // Add delay between attempts to let BLE stack reset
            if (attempt > 1) {
              print('[BLE] Waiting before retry...');
              await Future.delayed(Duration(milliseconds: 2000));
            }

            // Use shorter timeout for individual attempts
            await device.connect(
              timeout: Duration(seconds: 10),
              autoConnect:
                  false, // Disable autoConnect for more reliable connection
            );

            connected = true;
            _connectedDevice = device;
            print('[BLE] Device connected successfully on attempt $attempt');
            break;
          } catch (e) {
            print('[BLE] Connection attempt $attempt failed: ${e.toString()}');

            // Check for specific Android BLE errors
            if (e.toString().contains('133') ||
                e.toString().contains('status=133')) {
              print('[BLE] Detected Android BLE status=133 error - will retry');

              // Ensure device is disconnected before retry
              try {
                await device.disconnect();
                await Future.delayed(Duration(milliseconds: 500));
              } catch (_) {
                // Ignore disconnect errors
              }

              if (attempt == maxRetries) {
                throw Exception(
                  'Connection failed after $maxRetries attempts with status=133. This is an Android BLE stack issue. Try: 1) Turn Bluetooth off/on, 2) Restart the app, 3) Restart the device.',
                );
              }
            } else {
              // For other errors, don't retry
              throw e;
            }
          }
        }

        if (!connected) {
          throw Exception('Failed to connect after $maxRetries attempts');
        }
      }

      // Discover services with retry logic
      print('[BLE] Discovering services...');
      List<BluetoothService> services = [];
      int serviceDiscoveryRetries = 3;

      for (int attempt = 1; attempt <= serviceDiscoveryRetries; attempt++) {
        try {
          // Add small delay before service discovery
          await Future.delayed(Duration(milliseconds: 1000));
          services = await device.discoverServices();
          print('[BLE] Found ${services.length} services on attempt $attempt');
          break;
        } catch (e) {
          print(
            '[BLE] Service discovery attempt $attempt failed: ${e.toString()}',
          );
          if (attempt == serviceDiscoveryRetries) {
            throw Exception(
              'Service discovery failed after $serviceDiscoveryRetries attempts: ${e.toString()}',
            );
          }
          await Future.delayed(Duration(milliseconds: 1500));
        }
      }

      // Debug: Print all available services
      for (var service in services) {
        print('[BLE] Available service: ${service.uuid}');
        for (var char in service.characteristics) {
          print(
            '[BLE]   - Characteristic: ${char.uuid} (Properties: ${char.properties})',
          );
        }
      }

      // Find the fetal doppler service (be more flexible with UUID matching)
      BluetoothService? targetService;
      final targetServiceUUID = FetalDopplerConfig.serviceUUID.toLowerCase();

      for (var service in services) {
        final serviceUUID = service.uuid.toString().toLowerCase();
        if (serviceUUID.contains(targetServiceUUID.replaceAll('-', '')) ||
            serviceUUID == targetServiceUUID) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        // List available services for debugging
        final availableServices = services
            .map((s) => s.uuid.toString())
            .join(', ');
        throw Exception(
          'Fetal doppler service not found. Available services: $availableServices',
        );
      }

      print('[BLE] Found fetal doppler service: ${targetService.uuid}');

      // Get characteristics with better error handling
      print('[BLE] Getting characteristics...');

      // Find TX characteristic (for notifications from ESP32)
      BluetoothCharacteristic? txChar;
      final targetTxUUID =
          FetalDopplerConfig.txCharacteristicUUID.toLowerCase();

      for (var char in targetService.characteristics) {
        final charUUID = char.uuid.toString().toLowerCase();
        if (charUUID.contains(targetTxUUID.replaceAll('-', '')) ||
            charUUID == targetTxUUID) {
          txChar = char;
          break;
        }
      }

      if (txChar == null) {
        final availableChars = targetService.characteristics
            .map((c) => c.uuid.toString())
            .join(', ');
        throw Exception(
          'TX characteristic not found. Available characteristics: $availableChars',
        );
      }

      _txCharacteristic = txChar;
      print('[BLE] Found TX characteristic: ${_txCharacteristic!.uuid}');

      // Try to get RX characteristic but don't fail if not found (ESP32 might not have it)
      BluetoothCharacteristic? rxChar;
      final targetRxUUID =
          FetalDopplerConfig.rxCharacteristicUUID.toLowerCase();

      for (var char in targetService.characteristics) {
        final charUUID = char.uuid.toString().toLowerCase();
        if (charUUID.contains(targetRxUUID.replaceAll('-', '')) ||
            charUUID == targetRxUUID) {
          rxChar = char;
          break;
        }
      }

      _rxCharacteristic = rxChar;
      if (_rxCharacteristic != null) {
        print('[BLE] Found RX characteristic: ${_rxCharacteristic!.uuid}');
      } else {
        print('[BLE] RX characteristic not found (not required for ESP32)');
      }

      // Setup notifications for heart rate data with enhanced error handling
      print('[BLE] Setting up notifications...');

      // Check if characteristic supports notifications
      if (!_txCharacteristic!.properties.notify) {
        print(
          '[BLE] Warning: TX characteristic does not support notifications',
        );
        throw Exception('TX characteristic does not support notify property');
      }

      // Enable notifications with retry logic
      bool notificationsEnabled = false;
      int notifyRetries = 3;

      for (int attempt = 1; attempt <= notifyRetries; attempt++) {
        try {
          print(
            '[BLE] Enabling notifications (attempt $attempt/$notifyRetries)...',
          );
          await _txCharacteristic!.setNotifyValue(true);
          notificationsEnabled = true;
          break;
        } catch (e) {
          print(
            '[BLE] Failed to enable notifications on attempt $attempt: ${e.toString()}',
          );
          if (attempt == notifyRetries) {
            throw Exception(
              'Failed to enable notifications after $notifyRetries attempts: ${e.toString()}',
            );
          }
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }

      if (!notificationsEnabled) {
        throw Exception('Could not enable notifications');
      }

      print('[BLE] Notifications enabled successfully');

      // Subscribe to characteristic updates
      _characteristicSubscription = _txCharacteristic!.lastValueStream.listen(
        (data) {
          if (data.isNotEmpty) {
            _processHeartRateData(data);
          }
        },
        onError: (error) {
          print('[BLE] Characteristic stream error: ${error.toString()}');
          _errorController.add('Data stream error: ${error.toString()}');
        },
      );

      // Monitor device connection state
      _deviceStateSubscription = device.connectionState.listen((deviceState) {
        if (deviceState == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      state = BLEConnectionState.connected;
      return true;
    } catch (e) {
      state = BLEConnectionState.error;
      _errorController.add('Connection failed: ${e.toString()}');
      return false;
    }
  }

  // Start fetal heart rate monitoring
  Future<void> startMonitoring() async {
    print('[BLE] Starting monitoring - current state: ${state.name}');

    // Allow startMonitoring if already monitoring (idempotent operation)
    if (state != BLEConnectionState.connected &&
        state != BLEConnectionState.monitoring) {
      final error =
          'Cannot start monitoring - device not connected (state: ${state.name})';
      print('[BLE] $error');
      _errorController.add(error);
      throw Exception(error);
    }

    // If already monitoring, just return success
    if (state == BLEConnectionState.monitoring) {
      print('[BLE] Already monitoring - returning success');
      return;
    }

    try {
      print('[BLE] Attempting to start monitoring...');

      // Change state first to indicate monitoring has started
      state = BLEConnectionState.monitoring;
      print('[BLE] State changed to monitoring');

      // ESP32 automatically starts sending data when connected
      // Send command if RX characteristic is available
      if (_rxCharacteristic != null) {
        print('[BLE] Sending start monitoring command to ESP32...');
        final command = jsonEncode({'action': 'start_monitoring'});
        await _rxCharacteristic!.write(command.codeUnits);
        print('[BLE] Start command sent successfully');
      } else {
        print(
          '[BLE] No RX characteristic - ESP32 should auto-start sending data',
        );
      }

      // Simulation fallback removed. Only real BLE data is used.

      print('[BLE] Monitoring started successfully');
    } catch (e) {
      print('[BLE] Error starting monitoring: ${e.toString()}');

      // Even if command fails, ESP32 should auto-start, so continue monitoring
      // Keep monitoring state but log the error
      if (state != BLEConnectionState.monitoring) {
        state = BLEConnectionState.monitoring;
      }

      // Simulation fallback removed. Only real BLE data is used.

      print(
        '[BLE] Continuing monitoring despite command error (ESP32 auto-start)',
      );
    }
  }

  // Simulation/mock BLE data generation removed. Only real BLE data is used.

  // Stop monitoring
  Future<void> stopMonitoring() async {
    if (state == BLEConnectionState.monitoring) {
      try {
        // Stop simulation if running
        _simulationTimer?.cancel();
        _isSimulatingData = false;

        if (_rxCharacteristic != null) {
          final command = jsonEncode({'action': 'stop_monitoring'});
          await _rxCharacteristic!.write(command.codeUnits);
        }

        state = BLEConnectionState.connected;
      } catch (e) {
        // Even if command fails, change state
        state = BLEConnectionState.connected;
      }
    }
  }

  // Disconnect from device with proper cleanup
  Future<void> disconnect() async {
    print('[BLE] Starting disconnect process...');

    try {
      await stopMonitoring();
    } catch (e) {
      print(
        '[BLE] Error stopping monitoring during disconnect: ${e.toString()}',
      );
    }

    // Cancel subscriptions first
    try {
      await _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      print('[BLE] Characteristic subscription cancelled');
    } catch (e) {
      print(
        '[BLE] Error cancelling characteristic subscription: ${e.toString()}',
      );
    }

    try {
      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = null;
      print('[BLE] Device state subscription cancelled');
    } catch (e) {
      print(
        '[BLE] Error cancelling device state subscription: ${e.toString()}',
      );
    }

    // Disable notifications before disconnecting
    if (_txCharacteristic != null && _connectedDevice != null) {
      try {
        print('[BLE] Disabling notifications...');
        await _txCharacteristic!.setNotifyValue(false);
        print('[BLE] Notifications disabled');
      } catch (e) {
        print('[BLE] Error disabling notifications: ${e.toString()}');
      }
    }

    // Disconnect the device
    if (_connectedDevice != null) {
      try {
        print('[BLE] Disconnecting device...');
        await _connectedDevice!.disconnect();
        print('[BLE] Device disconnected successfully');
      } catch (e) {
        print('[BLE] Error disconnecting device: ${e.toString()}');
      }
    }

    // Clear references
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;

    state = BLEConnectionState.disconnected;
    print('[BLE] Disconnect process completed');
  }

  // Process incoming heart rate data
  void _processHeartRateData(List<int> data) {
    try {
      // Convert to string first - ESP32 sends text data like "137 (Normal)"
      final stringData = String.fromCharCodes(data);
      print('[BLE] Received data: "${stringData}" (${data.length} bytes)');

      // Cancel simulation since we're getting real data
      if (_isSimulatingData) {
        print('[BLE] Real data received - stopping simulation');
        _simulationTimer?.cancel();
        _isSimulatingData = false;
      }

      // Check if it's a valid ESP32 format string
      if (stringData.isNotEmpty && RegExp(r'\d+').hasMatch(stringData)) {
        print('[BLE] Parsing as ESP32 string format');
        final heartRateData = FetalHeartRateData.fromString(
          stringData,
          _gestationalAge,
        );

        // Skip BPM of 0 as it's likely initialization or error value
        // Note: Backend now supports BPM range 0-500, but 0 typically indicates no reading
        if (heartRateData.bpm == 0) {
          print('[BLE] Skipping BPM=0 (initialization/error value)');
          return;
        }

        print(
          '[BLE] Parsed BPM: ${heartRateData.bpm}, Classification: ${heartRateData.classification.name}',
        );
        _heartRateController.add(heartRateData);
      } else if (data.length >= 3) {
        print('[BLE] Parsing as binary format');
        // Fallback to binary format for other devices
        final uint8Data = Uint8List.fromList(data);
        final heartRateData = FetalHeartRateData.fromBytes(
          uint8Data,
          _gestationalAge,
        );

        // Skip BPM of 0
        if (heartRateData.bpm == 0) {
          print('[BLE] Skipping BPM=0 (initialization/error value)');
          return;
        }

        print('[BLE] Parsed BPM: ${heartRateData.bpm}');
        _heartRateController.add(heartRateData);
      } else {
        print('[BLE] Invalid data format - ignoring');
      }
    } catch (e) {
      print('[BLE] Data processing error: ${e.toString()}');
      _errorController.add('Data processing error: ${e.toString()}');
    }
  }

  // Handle device disconnection
  void _handleDisconnection() {
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    state = BLEConnectionState.disconnected;
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    _simulationTimer?.cancel();
    _heartRateController.close();
    _deviceListController.close();
    _errorController.close();
    super.dispose();
  }
}

// Provider for Fetal Doppler BLE Service
final fetalDopplerBLEProvider =
    StateNotifierProvider<FetalDopplerBLEService, BLEConnectionState>((ref) {
      return FetalDopplerBLEService();
    });
