// import 'package:dopply_app/screens/select_monitoring_result_screen.dart'; // Tidak dipakai
import 'package:flutter/material.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/services/share_monitoring_service.dart';

class ShareDoctorScreen extends StatefulWidget {
  const ShareDoctorScreen({Key? key}) : super(key: key);

  @override
  State<ShareDoctorScreen> createState() => _ShareDoctorScreenState();
}

class _ShareDoctorScreenState extends State<ShareDoctorScreen> {
  List<Patient> _doctors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAllDoctors();
  }

  Future<void> _fetchAllDoctors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dioResponse = await ApiClient().dio.get('/user/all-doctors');
      final data = dioResponse.data;
      if (data != null && data is Map && data['doctors'] is List) {
        setState(() {
          _doctors =
              (data['doctors'] as List).map<Patient>((item) {
                return Patient(
                  id: item['id'],
                  name: item['name'] ?? '',
                  email: item['email'] ?? '',
                  gestationalAge: null,
                  hpht: null,
                );
              }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Data dokter tidak valid.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal mengambil daftar dokter: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Dokter Tujuan')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                itemCount: _doctors.length,
                itemBuilder: (context, index) {
                  final doctor = _doctors[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(doctor.name),
                    subtitle: Text(doctor.email),
                    onTap: () async {
                      // Ambil token dan lakukan share ke dokter
                      final jwt = await StorageService.getToken() ?? '';
                      // Ambil monitoring result dari argumen route jika ada
                      final args = ModalRoute.of(context)?.settings.arguments;
                      int? recordId;
                      String notes = '';
                      if (args is Map && args.containsKey('recordId')) {
                        recordId = args['recordId'] as int?;
                        notes = args['notes'] as String? ?? '';
                      }
                      if (recordId != null) {
                        final success =
                            await ShareMonitoringService.shareMonitoring(
                              jwt: jwt,
                              recordId: recordId,
                              doctorId: doctor.id,
                              notes: notes,
                            );
                        if (success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Berhasil share hasil monitoring ke dokter',
                                ),
                              ),
                            );
                            Navigator.pop(context, true); // trigger refresh
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal share hasil monitoring!'),
                              ),
                            );
                            Navigator.pop(context, false);
                          }
                        }
                      } else {
                        // Jika tidak ada recordId, hanya pilih dokter
                        Navigator.pop(context, doctor);
                      }
                    },
                  );
                },
              ),
    );
  }
}
