import 'package:dopply_app/core/storage.dart';
// =============================================================================
// Patient Monitoring Screen - Improved UI with Better UX
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:dopply_app/screens/monitoring/monitoring_controller.dart';
import 'package:dopply_app/services/monitoring_service.dart';
import 'package:dopply_app/services/ble_service.dart';
import 'package:dopply_app/models/monitoring.dart';
import 'package:dopply_app/services/patient_service.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/widgets/common/button.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:dopply_app/screens/monitoring/monitoring_widgets.dart';
import 'package:dopply_app/screens/monitoring/monitoring_widgets_extra.dart';
import 'package:dopply_app/services/share_monitoring_service.dart';
import 'package:dopply_app/screens/share_doctor_screen.dart';

// Improved CardSection with better spacing and visual hierarchy
class CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final List<Widget>? actions;
  final IconData? icon;

  const CardSection({
    super.key,
    required this.title,
    required this.child,
    this.color,
    this.padding,
    this.actions,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                    ],
                    Text(title, style: AppTheme.heading3),
                  ],
                ),
                if (actions != null) Row(children: actions!),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

final fetalDopplerBLEServiceProvider =
    StateNotifierProvider<FetalDopplerBLEService, BLEConnectionState>(
      (ref) => FetalDopplerBLEService(),
    );

class PatientMonitoringScreen extends ConsumerStatefulWidget {
  const PatientMonitoringScreen({super.key});

  @override
  ConsumerState<PatientMonitoringScreen> createState() =>
      _PatientMonitoringScreenState();
}

class _PatientMonitoringScreenState
    extends ConsumerState<PatientMonitoringScreen> {
  // BLE state now managed by provider
  String? _selectedPatientId;
  List<Patient> _patients = [];
  bool _isLoadingPatients = false;
  Patient? _currentPatient; // Untuk pasien, data dari JWT
  final TextEditingController _addPatientEmailController =
      TextEditingController();
  String? _monitoringResult;
  int? _monitoringResultId;
  String? _userRole;
  final TextEditingController _notesController = TextEditingController();

  // Testing mode flag
  bool _testingMode = false;
  List<BpmDataPoint> _simulatedBpmData = [];

  @override
  void initState() {
    super.initState();
    MonitoringController.setApiTokenFromStorage();
    MonitoringController.fetchUserRole(
      setState: setState,
      setUserRole: (role) => _userRole = role,
      setCurrentPatient: (patient) => _currentPatient = patient,
      fetchPatients: _fetchPatients,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monitoringState = ref.watch(currentMonitoringProvider);
    final patientService = ref.read(patientServiceProvider);

    // Wait for _userRole to be loaded before showing UI
    if (_userRole == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Memuat informasi pengguna...',
                style: AppTheme.bodyText.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        debugPrint(
          '[MonitoringScreen] WillPopScope triggered, userRole: $_userRole',
        );
        if (_userRole == 'doctor') {
          context.go('/doctor');
        } else {
          context.go('/patient');
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                if (_userRole == 'doctor') {
                  context.go('/doctor');
                } else {
                  context.go('/patient');
                }
              }
            },
          ),
          title: const Text('Monitoring Janin'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          onRefresh: _fetchPatients,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Testing mode toggle
                Row(
                  children: [
                    Switch(
                      value: _testingMode,
                      onChanged: (val) {
                        setState(() {
                          _testingMode = val;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Testing Mode (tanpa ESP32)'),
                  ],
                ),
                // Patient selection section (only for non-patient users)
                if (_userRole != 'patient') ...[
                  _buildPatientManagementSection(patientService),
                  const SizedBox(height: 16),
                ],

                // Connection status with improved visual feedback
                if (!_testingMode) _buildConnectionStatusCard(monitoringState),
                if (!_testingMode) const SizedBox(height: 16),

                // Show chart if there is data, even after monitoring is finished
                if (!_testingMode &&
                    monitoringState.realTimeData.isNotEmpty) ...[
                  _buildMonitoringSection(monitoringState),
                  const SizedBox(height: 16),
                ],
                if (_testingMode && _simulatedBpmData.isNotEmpty) ...[
                  _buildSimulatedMonitoringSection(),
                  const SizedBox(height: 16),
                ],

                // Control buttons with improved layout
                _buildControlSection(monitoringState),

                // Error display with better styling
                if (monitoringState.error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorDisplay(monitoringState.error!),
                ],

                // Results section with improved UI
                if (_monitoringResult != null) ...[
                  const SizedBox(height: 16),
                  _buildResultsSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientManagementSection(PatientService patientService) {
    return CardSection(
      title: 'Manajemen Pasien',
      icon: Icons.people,
      child: Column(
        children: [
          _buildPatientSelector(),
          const SizedBox(height: 16),
          _buildAddPatientForm(patientService),
        ],
      ),
    );
  }

  Widget _buildMonitoringSection(MonitoringState state) {
    return Column(
      children: [
        _buildRealTimeChart(state.realTimeData),
        const SizedBox(height: 16),
        _buildCurrentBpmDisplay(state.realTimeData),
      ],
    );
  }

  Widget _buildSimulatedMonitoringSection() {
    // Simulasi data BPM
    if (_simulatedBpmData.isEmpty) {
      // Generate 30 data BPM acak antara 120-140
      _simulatedBpmData = List.generate(
        30,
        (i) => BpmDataPoint(
          bpm: 120 + (i % 20),
          timestamp: DateTime.now().add(Duration(seconds: i)),
        ),
      );
    }
    return Column(
      children: [
        _buildRealTimeChart(_simulatedBpmData),
        const SizedBox(height: 16),
        _buildCurrentBpmDisplay(_simulatedBpmData),
      ],
    );
  }

  Widget _buildControlSection(MonitoringState state) {
    final bleState = ref.watch(fetalDopplerBLEServiceProvider);

    return CardSection(
      title: 'Kontrol Monitoring',
      icon: Icons.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_testingMode && !state.isConnected) ...[
            AppButton(
              text:
                  bleState == BLEConnectionState.scanning
                      ? 'Menghubungkan ESP32...'
                      : 'Hubungkan ESP32',
              onPressed:
                  bleState == BLEConnectionState.scanning
                      ? null
                      : _connectEsp32,
              isLoading: bleState == BLEConnectionState.scanning,
            ),
          ],

          if ((!_testingMode && state.isConnected && !state.isMonitoring) ||
              (_testingMode && !state.isMonitoring)) ...[
            AppButton(
              text: 'Mulai Monitoring',
              onPressed: () async {
                debugPrint('[DEBUG] Mulai Monitoring ditekan');
                if (_testingMode) {
                  ref
                      .read(currentMonitoringProvider.notifier)
                      .setMonitoring(true);
                  setState(() {
                    // Isi data simulasi setiap mulai monitoring
                    _simulatedBpmData = List.generate(
                      30,
                      (i) => BpmDataPoint(
                        bpm: 120 + (i % 20),
                        timestamp: DateTime.now().add(Duration(seconds: i)),
                      ),
                    );
                  });
                  debugPrint(
                    '[DEBUG] Testing mode aktif, _simulatedBpmData diisi',
                  );
                } else {
                  debugPrint('[DEBUG] Memanggil _startMonitoring()');
                  _startMonitoring();
                }
              },
              backgroundColor: Colors.green,
            ),
          ],

          if (state.isMonitoring) ...[
            AppButton(
              text: 'Selesai Monitoring',
              onPressed: () async {
                debugPrint('[DEBUG] Selesai Monitoring ditekan');
                if (_testingMode) {
                  ref
                      .read(currentMonitoringProvider.notifier)
                      .setMonitoring(false);
                  debugPrint('[DEBUG] Testing mode, setMonitoring(false)');
                  await _submitSimulatedMonitoringSession();
                  debugPrint(
                    '[DEBUG] submitSimulatedMonitoringSession selesai',
                  );
                } else {
                  debugPrint('[DEBUG] Memanggil _stopMonitoring()');
                  await _stopMonitoring();
                  debugPrint('[DEBUG] Memanggil _submitMonitoringSession()');
                  await _submitMonitoringSession();
                  debugPrint('[DEBUG] submitMonitoringSession selesai');
                }
              },
              backgroundColor: Colors.red,
            ),
          ],

          if (!_testingMode && state.isConnected) ...[
            const SizedBox(height: 8),
            AppButton(
              text: 'Putuskan Koneksi',
              onPressed: _disconnect,
              backgroundColor: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitSimulatedMonitoringSession() async {
    // Simulasi submit ke backend menggunakan _simulatedBpmData
    // Implementasi tergantung pada MonitoringController.submitMonitoringSession
    // Anda bisa modifikasi agar menerima data custom
    // Debugging: print gestational age for selected/current patient
    Patient? debugPatient;
    if (_userRole == 'patient' && _currentPatient != null) {
      debugPatient = _currentPatient;
    } else {
      debugPatient = _patients.firstWhere(
        (p) => p.id.toString() == _selectedPatientId,
        orElse:
            () =>
                _patients.isNotEmpty
                    ? _patients.first
                    : Patient(
                      id: 0,
                      name: 'Unknown',
                      email: '',
                      gestationalAge: 0,
                    ),
      );
    }
    debugPrint(
      '[DEBUG] Submit Monitoring: patientId=${debugPatient?.id}, gestationalAge=${debugPatient?.gestationalAge}',
    );
    await MonitoringController.submitMonitoringSession(
      context: context,
      ref: ref,
      userRole: _userRole,
      currentPatient: _currentPatient,
      patients: _patients,
      selectedPatientId: _selectedPatientId,
      setState: setState,
      setMonitoringResult: (result) => _monitoringResult = result,
      setMonitoringResultId: (id) => _monitoringResultId = id,
      customBpmData: _simulatedBpmData.map((e) => e.bpm).toList(),
    );
  }

  Widget _buildResultsSection() {
    return CardSection(
      title: 'Hasil Klasifikasi',
      icon: Icons.assessment,
      color: Colors.green.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display the monitoring result
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hasil Monitoring:',
                  style: AppTheme.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _monitoringResult ?? 'Tidak ada hasil',
                  style: AppTheme.heading3.copyWith(
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Notes section hanya untuk non-pasien
          if (_userRole != 'patient') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Tambahkan catatan untuk hasil monitoring ini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Action buttons with overflow protection
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              if (_userRole == 'patient' && _monitoringResultId != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 120,
                    maxWidth: 160,
                  ),
                  child: AppButton(
                    text: 'Share Dokter',
                    onPressed: () async {
                      // Tampilkan UI pemilihan dokter
                      final selectedDoctor = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShareDoctorScreen(),
                        ),
                      );
                      if (selectedDoctor is Patient) {
                        final doctorId = selectedDoctor.id;
                        final success =
                            await ShareMonitoringService.shareMonitoring(
                              jwt: await StorageService.getToken() ?? '',
                              recordId: _monitoringResultId!,
                              doctorId: doctorId,
                              notes: _notesController.text.trim(),
                            );
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Berhasil share ke dokter!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal share ke dokter!'),
                            ),
                          );
                        }
                      }
                    },
                    backgroundColor: Colors.blue,
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
                child: AppButton(
                  text: 'Simpan',
                  onPressed: _saveMonitoringResult,
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    return PatientSelector(
      patients: _patients,
      selectedPatientId: _selectedPatientId,
      isLoading: _isLoadingPatients,
      onChanged: (val) {
        setState(() {
          _selectedPatientId = val;
        });
      },
      onRefresh: _fetchPatients,
    );
  }

  Widget _buildAddPatientForm(PatientService patientService) {
    return AddPatientForm(
      emailController: _addPatientEmailController,
      patientService: patientService,
      onSuccess: _fetchPatients,
    );
  }

  Future<void> _fetchPatients() async {
    await MonitoringController.fetchPatients(
      context: context,
      ref: ref,
      setState: setState,
      setPatients: (patients) => _patients = patients,
      setSelectedPatientId: (id) => _selectedPatientId = id,
      setIsLoading: (loading) => _isLoadingPatients = loading,
    );
  }

  Widget _buildConnectionStatusCard(MonitoringState state) {
    return ConnectionStatusCard(
      isConnected: state.isConnected,
      isMonitoring: state.isMonitoring,
    );
  }

  Widget _buildRealTimeChart(List<BpmDataPoint> data) {
    return RealTimeChartCard(data: data);
  }

  Widget _buildCurrentBpmDisplay(List<BpmDataPoint> data) {
    final currentBpm = data.isNotEmpty ? data.last.bpm : 0;
    return CurrentBpmCard(currentBpm: currentBpm);
  }

  Widget _buildErrorDisplay(String error) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terjadi Kesalahan',
                    style: AppTheme.heading3.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: AppTheme.bodyText.copyWith(
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(currentMonitoringProvider.notifier).clearError();
              },
              color: Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectEsp32() async {
    await MonitoringController.connectEsp32(
      ref: ref,
      connectToDevice: _connectToDevice,
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await MonitoringController.connectToDevice(
      context: context,
      ref: ref,
      device: device,
    );
  }

  Future<void> _startMonitoring() async {
    await MonitoringController.startMonitoring(context: context, ref: ref);
  }

  Future<void> _stopMonitoring() async {
    await MonitoringController.stopMonitoring(context: context, ref: ref);
  }

  Future<void> _submitMonitoringSession() async {
    final monitoringState = ref.read(currentMonitoringProvider);
    final customBpmData =
        _testingMode
            ? _simulatedBpmData.map((e) => e.bpm).toList()
            : (_userRole == 'patient' && monitoringState.realTimeData.isNotEmpty
                ? monitoringState.realTimeData.map((e) => e.bpm).toList()
                : null);

    debugPrint('[DEBUG] _submitMonitoringSession called');
    debugPrint('userRole: [32m$_userRole[0m');
    debugPrint('customBpmData: [36m$customBpmData[0m');
    debugPrint('selectedPatientId: $_selectedPatientId');
    debugPrint('currentPatient: $_currentPatient');

    await MonitoringController.submitMonitoringSession(
      context: context,
      ref: ref,
      userRole: _userRole,
      currentPatient: _currentPatient,
      patients: _patients,
      selectedPatientId: _selectedPatientId,
      setState: setState,
      setMonitoringResult: (result) => _monitoringResult = result,
      setMonitoringResultId: (id) => _monitoringResultId = id,
      customBpmData: customBpmData,
    );
  }

  Future<void> _disconnect() async {
    await MonitoringController.disconnect(context: context, ref: ref);
  }

  // Fungsi untuk share hasil monitoring ke dokter

  // Fungsi untuk simpan hasil monitoring ke database
  Future<void> _saveMonitoringResult() async {
    final monitoringState = ref.read(currentMonitoringProvider);
    final customBpmData =
        _testingMode
            ? _simulatedBpmData.map((e) => e.bpm).toList()
            : (_userRole == 'patient' && monitoringState.realTimeData.isNotEmpty
                ? monitoringState.realTimeData.map((e) => e.bpm).toList()
                : null);

    debugPrint('[DEBUG] _saveMonitoringResult called');
    debugPrint('userRole: [32m$_userRole[0m');
    debugPrint('customBpmData: [36m$customBpmData[0m');
    debugPrint('notes: ${_notesController.text.trim()}');
    debugPrint('selectedPatientId: $_selectedPatientId');
    debugPrint('currentPatient: $_currentPatient');

    await MonitoringController.saveMonitoringResult(
      context: context,
      ref: ref,
      userRole: _userRole,
      currentPatient: _currentPatient,
      patients: _patients,
      selectedPatientId: _selectedPatientId,
      notes: _notesController.text.trim(),
      customBpmData: customBpmData,
      setMonitoringResultId: (id) {
        _monitoringResultId = id;
        setState(() {}); // Refresh UI agar tombol Share Dokter muncul
      },
    );
  }
}
