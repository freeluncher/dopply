import 'package:flutter/material.dart';
import 'package:dopply_app/models/patient.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:dopply_app/widgets/common/button.dart';
import 'package:dopply_app/services/patient_service.dart';

class PatientSelector extends StatelessWidget {
  final List<Patient> patients;
  final String? selectedPatientId;
  final bool isLoading;
  final void Function(String?) onChanged;
  final VoidCallback onRefresh;

  const PatientSelector({
    super.key,
    required this.patients,
    required this.selectedPatientId,
    required this.isLoading,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_search,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text('Pilih Pasien', style: AppTheme.heading3),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: onRefresh,
                    tooltip: 'Refresh daftar pasien',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Memuat daftar pasien...'),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        patients.isEmpty ? Colors.red[300]! : Colors.grey[300]!,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: patients.isNotEmpty ? selectedPatientId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Pilih Pasien',
                    prefixIcon: Icon(
                      Icons.person,
                      color:
                          patients.isEmpty
                              ? Colors.red[400]
                              : Theme.of(context).primaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    labelStyle: TextStyle(
                      color: patients.isEmpty ? Colors.red[600] : null,
                    ),
                  ),
                  items:
                      patients.isNotEmpty
                          ? patients.map((p) {
                            return DropdownMenuItem(
                              value: p.id.toString(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (p.email.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          p.email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList()
                          : [
                            DropdownMenuItem(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.red[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tidak ada pasien tersedia',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                  onChanged: patients.isNotEmpty ? onChanged : null,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),

            // Patient details section
            if (selectedPatientId != null && patients.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final selected = patients.firstWhere(
                      (p) => p.id.toString() == selectedPatientId,
                      orElse: () => patients.first,
                    );
                    final gestAge =
                        selected.gestationalAge != null
                            ? '${selected.gestationalAge} minggu'
                            : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Informasi Pasien',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.person, 'Nama', selected.name),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.email, 'Email', selected.email),
                        if (gestAge != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Usia Kehamilan',
                            gestAge,
                          ),
                        ],
                        if (selected.hpht != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.event,
                            'HPHT',
                            selected.hpht!
                                .toLocal()
                                .toIso8601String()
                                .substring(0, 10),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],

            // Empty state
            if (patients.isEmpty && !isLoading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada pasien yang terdaftar. Silakan tambahkan pasien terlebih dahulu.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AddPatientForm extends StatefulWidget {
  final TextEditingController emailController;
  final PatientService patientService;
  final VoidCallback onSuccess;

  const AddPatientForm({
    super.key,
    required this.emailController,
    required this.patientService,
    required this.onSuccess,
  });

  @override
  State<AddPatientForm> createState() => _AddPatientFormState();
}

class _AddPatientFormState extends State<AddPatientForm> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text('Tambah Pasien', style: AppTheme.heading3),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                labelText: 'Email Pasien',
                prefixIcon: Icon(
                  Icons.email,
                  color: Theme.of(context).primaryColor,
                ),
                errorText: _errorMessage,
                enabled: !_isLoading,
              ),
              onChanged: (value) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Tambah Pasien',
                onPressed: _isLoading ? null : _handleAddPatient,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddPatient() async {
    final email = widget.emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email tidak boleh kosong';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Format email tidak valid';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.patientService.addPatient(email);
      final success = result.$1;
      final errorMsg = result.$2;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Pasien berhasil ditambahkan'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          widget.emailController.clear();
          widget.onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMsg ?? 'Gagal menambah pasien')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }
}
