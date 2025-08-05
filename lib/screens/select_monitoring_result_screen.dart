import 'package:flutter/material.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/services/monitoring_result_service.dart';
import 'package:dopply_app/services/share_monitoring_service.dart';
import 'package:dopply_app/core/storage.dart';

class SelectMonitoringResultScreen extends StatefulWidget {
  final Patient selectedDoctor;
  const SelectMonitoringResultScreen({Key? key, required this.selectedDoctor})
    : super(key: key);

  @override
  State<SelectMonitoringResultScreen> createState() =>
      _SelectMonitoringResultScreenState();
}

class _SelectMonitoringResultScreenState
    extends State<SelectMonitoringResultScreen> {
  List<Map<String, dynamic>> monitoringResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    final results =
        await MonitoringResultService.fetchPatientMonitoringResults();
    setState(() {
      monitoringResults = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Hasil Monitoring')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Dokter tujuan: ${widget.selectedDoctor.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : monitoringResults.isEmpty
                    ? const Center(
                      child: Text('Tidak ada hasil monitoring ditemukan'),
                    )
                    : ListView.builder(
                      itemCount: monitoringResults.length,
                      itemBuilder: (context, index) {
                        final result = monitoringResults[index];
                        return ListTile(
                          leading: const Icon(Icons.analytics),
                          title: Text(
                            result['title'] ?? 'Monitoring #${result['id']}',
                          ),
                          subtitle: Text(result['date'] ?? ''),
                          onTap: () async {
                            final jwt = await StorageService.getToken() ?? '';
                            final recordId = result['id'];
                            final doctorId = widget.selectedDoctor.id;
                            final notes = result['notes'] ?? '';
                            final success =
                                await ShareMonitoringService.shareMonitoring(
                                  jwt: jwt,
                                  recordId: recordId,
                                  doctorId: doctorId,
                                  notes: notes,
                                );
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Berhasil share hasil monitoring ke ${widget.selectedDoctor.name}',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal share hasil monitoring!',
                                  ),
                                ),
                              );
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
