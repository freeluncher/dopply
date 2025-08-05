import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/screens/share_doctor_screen.dart';
import 'package:dopply_app/services/share_monitoring_service.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:flutter/material.dart';
import 'package:dopply_app/core/app_navigation.dart' as app_nav;
import 'package:dopply_app/core/api_client.dart';

class MonitoringResult {
  final int id;
  final String patientName;
  final int? doctorId;
  final String? doctorName;
  final String? doctorEmail;
  final String classification;
  final double averageBpm;
  final int gestationalAge;
  final String notes;
  final String doctorNotes;
  final bool sharedWithDoctor;

  MonitoringResult({
    required this.id,
    required this.patientName,
    this.doctorId,
    this.doctorName,
    this.doctorEmail,
    required this.classification,
    required this.averageBpm,
    required this.gestationalAge,
    required this.notes,
    required this.doctorNotes,
    required this.sharedWithDoctor,
  });

  factory MonitoringResult.fromJson(Map<String, dynamic> json) {
    return MonitoringResult(
      id: json['id'],
      patientName: json['patient_name'] ?? '',
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'],
      doctorEmail: json['doctor_email'],
      classification: json['classification'] ?? '',
      averageBpm: (json['average_bpm'] ?? 0).toDouble(),
      gestationalAge: json['gestational_age'] ?? 0,
      notes: json['notes'] ?? '',
      doctorNotes: json['doctor_notes'] ?? '',
      sharedWithDoctor:
          (json['shared_with_doctor'] is bool &&
                      json['shared_with_doctor'] == true) ||
                  (json['shared_with_doctor'] is int &&
                      json['shared_with_doctor'] == 1)
              ? true
              : false,
    );
  }
}

Future<List<MonitoringResult>> fetchMonitoringHistory(
  String jwtToken, {
  int? patientId,
  int skip = 0,
  int limit = 20,
}) async {
  final uri = Uri.parse('${ApiConfig.baseUrl}/monitoring/history').replace(
    queryParameters: {
      if (patientId != null) 'patient_id': patientId.toString(),
      'skip': skip.toString(),
      'limit': limit.toString(),
    },
  );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    },
  );

  final jsonResponse = json.decode(response.body);
  // Support new backend response structure
  List records = [];
  if (jsonResponse['records'] is List) {
    records = jsonResponse['records'];
  } else if (jsonResponse['data'] is List) {
    records = jsonResponse['data'];
  }
  if (records.isNotEmpty) {
    return records.map((item) => MonitoringResult.fromJson(item)).toList();
  } else {
    // Handle error, show message if needed
    return [];
  }
}

class HistoryScreen extends StatefulWidget {
  final int? patientId;

  const HistoryScreen({this.patientId, Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _role;
  late Future<List<MonitoringResult>> _futureHistory;

  @override
  void initState() {
    super.initState();
    _futureHistory = _getHistory();
    _getRole();
  }

  Future<void> _getRole() async {
    final userJson = await StorageService.getUserData();
    if (userJson != null && userJson.isNotEmpty) {
      final userMap = jsonDecode(userJson);
      setState(() {
        _role = userMap['role'];
      });
    }
  }

  Future<List<MonitoringResult>> _getHistory() async {
    final token = await StorageService.getToken();
    final userJson = await StorageService.getUserData();
    if (token == null ||
        token.isEmpty ||
        userJson == null ||
        userJson.isEmpty) {
      return [];
    }
    final userMap = jsonDecode(userJson);
    final userId = userMap['id'];
    final role = userMap['role'];
    final allResults = await fetchMonitoringHistory(token);
    if (role == 'patient') {
      // Pasien hanya melihat data miliknya (nama atau email sama dengan user)
      final userName = userMap['name']?.toString().trim();
      final userEmail = userMap['email']?.toString().trim();
      return allResults
          .where(
            (r) =>
                r.patientName.trim() == userName ||
                r.patientName.trim() == userEmail,
          )
          .toList();
    } else if (role == 'doctor') {
      // Dokter hanya melihat data yang dibagikan ke dia (doctorId sama dan sharedWithDoctor true)
      return allResults
          .where(
            (r) =>
                r.doctorId != null &&
                r.doctorId == userId &&
                r.sharedWithDoctor == true,
          )
          .toList();
    } else {
      // Admin: tampilkan semua
      return allResults;
    }
  }

  Color _getClassificationColor(String classification) {
    switch (classification.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'abnormal':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getClassificationIcon(String classification) {
    switch (classification.toLowerCase()) {
      case 'normal':
        return Icons.check_circle;
      case 'abnormal':
        return Icons.warning;
      case 'warning':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Pastikan navigasi berjalan sebelum return false
        Future.delayed(const Duration(milliseconds: 100), () {
          app_nav.navigateBackByRole(context, _role);
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Riwayat Monitoring',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: Colors.blue[600],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Kembali ke Dashboard',
            onPressed: () {
              app_nav.navigateBackByRole(context, _role);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.dashboard, color: Colors.white),
              tooltip: 'Dashboard',
              onPressed: () {
                app_nav.toDashboardByRole(context, _role);
              },
            ),
          ],
        ),
        body: FutureBuilder<List<MonitoringResult>>(
          future: _futureHistory,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal memuat data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan coba lagi nanti',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }
            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada riwayat monitoring',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Riwayat monitoring akan muncul di sini',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _futureHistory = _getHistory();
                });
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final result = history[index];
                  // DEBUG: print doctorName and doctorEmail for each record
                  // ignore: avoid_print
                  print(
                    '[DEBUG] MonitoringResult id=${result.id} doctorName=${result.doctorName} doctorEmail=${result.doctorEmail} sharedWithDoctor=${result.sharedWithDoctor}',
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _showDetailDialog(context, result);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue[600],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.patientName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Usia kandungan: ${result.gestationalAge} minggu',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        result.sharedWithDoctor
                                            ? (result.doctorName != null &&
                                                    result.doctorName!
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty
                                                ? 'Dibagikan ke dokter: ${result.doctorName}'
                                                : (result.doctorEmail != null &&
                                                        result.doctorEmail!
                                                            .toString()
                                                            .trim()
                                                            .isNotEmpty
                                                    ? 'Dibagikan ke dokter: ${result.doctorEmail}'
                                                    : 'Sudah dibagikan ke dokter'))
                                            : 'Belum dibagikan ke dokter',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              result.sharedWithDoctor
                                                  ? Colors.teal[700]
                                                  : Colors.red[400],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getClassificationColor(
                                      result.classification,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getClassificationColor(
                                        result.classification,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getClassificationIcon(
                                          result.classification,
                                        ),
                                        size: 16,
                                        color: _getClassificationColor(
                                          result.classification,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        result.classification,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _getClassificationColor(
                                            result.classification,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rata-rata BPM: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${result.averageBpm.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (result.notes.isNotEmpty ||
                                result.doctorNotes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notes,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ada catatan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (_role != 'doctor' &&
                                !(_role == 'patient' &&
                                    result.sharedWithDoctor))
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share ke Dokter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    // Navigasi ke pemilihan dokter, lalu share
                                    final refresh = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ShareDoctorScreen(),
                                        settings: RouteSettings(
                                          arguments: {
                                            'recordId': result.id,
                                            'notes': result.notes,
                                          },
                                        ),
                                      ),
                                    );
                                    // Jika share sukses, refresh data
                                    if (refresh == true) {
                                      setState(() {
                                        _futureHistory = _getHistory();
                                      });
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, MonitoringResult result) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Detail Monitoring',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'Nama Pasien',
                    value: result.patientName,
                    iconColor: Colors.blue[600]!,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: _getClassificationIcon(result.classification),
                    label: 'Klasifikasi',
                    value: result.classification,
                    iconColor: _getClassificationColor(result.classification),
                    valueColor: _getClassificationColor(result.classification),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.favorite,
                    label: 'Rata-rata BPM',
                    value: result.averageBpm.toStringAsFixed(1),
                    iconColor: Colors.red[400]!,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Usia Kandungan',
                    value: '${result.gestationalAge} minggu',
                    iconColor: Colors.green[600]!,
                  ),
                  if (result.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.note,
                      label: 'Catatan',
                      value: result.notes,
                      iconColor: Colors.orange[600]!,
                      isMultiline: true,
                    ),
                  ],
                  if (result.doctorNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.local_hospital,
                      label: 'Catatan Dokter',
                      value: result.doctorNotes,
                      iconColor: Colors.purple[600]!,
                      isMultiline: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? valueColor,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
