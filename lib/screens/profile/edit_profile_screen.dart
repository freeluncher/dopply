import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/services/patient_service.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:dopply_app/core/api_client.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _errorMsg;

  // Biodata fields
  int? patientId;
  int? userId;
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  DateTime? hpht;
  DateTime? birthDate;
  TextEditingController addressController = TextEditingController();
  TextEditingController medicalNoteController = TextEditingController();
  String? _currentPhotoUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    medicalNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final userJson = await StorageService.getUserData();

      if (userJson != null && userJson.isNotEmpty) {
        final userMap = jsonDecode(userJson);

        // Ambil patient_id dari JWT/storage
        patientId = userMap['patient_id'] ?? userMap['id'];
        userId = userMap['user_id'] ?? userMap['id'];

        // Set data dasar dari user data storage
        setState(() {
          nameController.text = userMap['name'] ?? '';
          emailController.text = userMap['email'] ?? '';

          // Parse tanggal jika ada
          if (userMap['hpht'] != null) {
            try {
              hpht = DateTime.parse(userMap['hpht']);
            } catch (e) {
              print('[EditProfile] Error parsing HPHT: $e');
            }
          }

          if (userMap['birth_date'] != null) {
            try {
              birthDate = DateTime.parse(userMap['birth_date']);
            } catch (e) {
              print('[EditProfile] Error parsing birth_date: $e');
            }
          }

          addressController.text = userMap['address'] ?? '';
          medicalNoteController.text = userMap['medical_note'] ?? '';
          _currentPhotoUrl = userMap['photo_url'] ?? '';
        });

        print('[EditProfile] Patient data loaded from storage: $userMap');
        print(
          '[EditProfile] Patient ID (for endpoint): $patientId, User ID: $userId',
        );

        // Optional: Coba ambil data terbaru dari backend jika endpoint tersedia
        if (patientId != null) {
          try {
            final patientService = ref.read(patientServiceProvider);
            final patient = await patientService.getPatientProfile(patientId!);

            if (patient != null) {
              setState(() {
                nameController.text = patient.name;
                emailController.text = patient.email;
                hpht = patient.hpht;
                birthDate = patient.birthDate;
                addressController.text = patient.address ?? '';
                medicalNoteController.text = patient.medicalNote ?? '';
              });
              print(
                '[EditProfile] Patient data updated from backend: ${patient.toJson()}',
              );
            }
          } catch (e) {
            print('[EditProfile] Backend unavailable, using storage data: $e');
            // Tidak perlu menampilkan error ke user karena data dari storage sudah cukup
          }
        }
      } else {
        setState(() {
          _errorMsg =
              'Data pasien tidak ditemukan. Pastikan Anda sudah login sebagai pasien.';
        });
      }
    } catch (e) {
      print('[EditProfile] Error loading patient data: $e');
      setState(() {
        _errorMsg = 'Terjadi kesalahan saat memuat data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      // Validasi ukuran file (max 5MB)
      final int fileSize = await File(image.path).length();
      if (fileSize > 5 * 1024 * 1024) {
        setState(() {
          _errorMsg = 'Ukuran file terlalu besar. Maksimal 5MB.';
        });
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
        _errorMsg = null;
        _selectedImageFile = File(image.path);
      });

      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMsg = 'Token tidak ditemukan. Silakan login ulang.';
          _isUploadingPhoto = false;
        });
        return;
      }

      final url = '${ApiConfig.baseUrl}/patient/profile/photo';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      final responseString = await response.stream.bytesToString();
      final respJson = jsonDecode(responseString);

      if (response.statusCode == 200 && respJson['status'] == 'success') {
        setState(() {
          _currentPhotoUrl = respJson['photo_url'];
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil berhasil diupload!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        setState(() {
          _errorMsg = respJson['message'] ?? 'Gagal upload foto profil';
          _isUploadingPhoto = false;
          _selectedImageFile = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Terjadi kesalahan saat upload foto: ${e.toString()}';
        _isUploadingPhoto = false;
        _selectedImageFile = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final token = await StorageService.getToken();
      final url = '${ApiConfig.baseUrl}/patient/$patientId';
      final body = jsonEncode({
        'user_id': userId,
        'name': nameController.text,
        'email': emailController.text,
        'hpht': hpht?.toIso8601String(),
        'birth_date': birthDate?.toIso8601String(),
        'address': addressController.text,
        'medical_note': medicalNoteController.text,
        'photo_url': _currentPhotoUrl,
      });

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final respJson = jsonDecode(response.body);
      if (response.statusCode == 200 && respJson['status'] == 'success') {
        // Update local storage
        await StorageService.saveUserData(jsonEncode(respJson['data']));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Biodata berhasil diperbarui!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          // Redirect to dashboard according to role
          final role = await StorageService.getUserRole();
          if (role == 'doctor') {
            context.go('/doctor_dashboard');
          } else {
            context.go('/patient');
          }
        }
      } else {
        setState(() {
          _errorMsg = respJson['message'] ?? 'Gagal update biodata';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Terjadi kesalahan: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Biodata'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Fallback: redirect to dashboard sesuai role
              StorageService.getUserRole().then((role) {
                if (role == 'doctor') {
                  context.go('/doctor_dashboard');
                } else {
                  context.go('/patient');
                }
              });
            }
          },
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data pasien...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        Card(
                          elevation: 0,
                          color: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.borderColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Biodata Pasien',
                                        style: AppTheme.heading2,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Lengkapi informasi biodata Anda',
                                        style: AppTheme.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Error Message
                        if (_errorMsg != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Form Fields Card
                        Card(
                          elevation: 0,
                          color: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.borderColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Informasi Pribadi',
                                  style: AppTheme.heading3,
                                ),
                                const SizedBox(height: 16),

                                // Name Field
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap',
                                    hintText: 'Masukkan nama lengkap',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Nama wajib diisi'
                                              : null,
                                ),
                                const SizedBox(height: 16),

                                // Email Field
                                TextFormField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'Masukkan alamat email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email wajib diisi';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(v)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // HPHT Field
                                _DatePickerField(
                                  label: 'Hari Pertama Haid Terakhir (HPHT)',
                                  value: hpht,
                                  onChanged:
                                      (date) => setState(() => hpht = date),
                                  icon: Icons.calendar_today_outlined,
                                ),
                                const SizedBox(height: 16),

                                // Birth Date Field
                                _DatePickerField(
                                  label: 'Tanggal Lahir',
                                  value: birthDate,
                                  onChanged:
                                      (date) =>
                                          setState(() => birthDate = date),
                                  icon: Icons.cake_outlined,
                                ),
                                const SizedBox(height: 16),

                                // Address Field
                                TextFormField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Alamat',
                                    hintText: 'Masukkan alamat lengkap',
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),

                                // Medical Note Field
                                TextFormField(
                                  controller: medicalNoteController,
                                  decoration: const InputDecoration(
                                    labelText: 'Catatan Medis',
                                    hintText:
                                        'Masukkan catatan medis (opsional)',
                                    prefixIcon: Icon(
                                      Icons.medical_information_outlined,
                                    ),
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 24),

                                // Photo Upload Section
                                Text('Foto Profil', style: AppTheme.heading3),
                                const SizedBox(height: 16),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Upload Foto Profil',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Current Photo or Placeholder
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          // Photo Preview
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              child:
                                                  _selectedImageFile != null
                                                      ? Image.file(
                                                        _selectedImageFile!,
                                                        fit: BoxFit.cover,
                                                      )
                                                      : (_currentPhotoUrl !=
                                                              null &&
                                                          _currentPhotoUrl!
                                                              .isNotEmpty)
                                                      ? Image.network(
                                                        _currentPhotoUrl!
                                                                .startsWith(
                                                                  'http',
                                                                )
                                                            ? _currentPhotoUrl!
                                                            : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$_currentPhotoUrl',
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return const Icon(
                                                            Icons.person,
                                                            size: 40,
                                                            color: Colors.grey,
                                                          );
                                                        },
                                                      )
                                                      : const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Upload Button
                                          ElevatedButton.icon(
                                            onPressed:
                                                _isLoading || _isUploadingPhoto
                                                    ? null
                                                    : _pickAndUploadPhoto,
                                            icon:
                                                _isUploadingPhoto
                                                    ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                    : const Icon(
                                                      Icons.upload_outlined,
                                                      size: 18,
                                                    ),
                                            label: Text(
                                              _isUploadingPhoto
                                                  ? 'Mengupload...'
                                                  : 'Pilih Foto',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme
                                                  .primaryColor
                                                  .withOpacity(0.1),
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),

                                          if (_currentPhotoUrl != null &&
                                              _currentPhotoUrl!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Foto profil saat ini',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Upload Info
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Format: JPG/PNG, Maksimal 5MB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.save_outlined,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Simpan Biodata',
                                          style: AppTheme.button,
                                        ),
                                      ],
                                    ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final IconData icon;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: AppTheme.surfaceColor,
                  onSurface: AppTheme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon:
              value != null
                  ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => onChanged(null),
                  )
                  : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value != null ? _formatDate(value!) : 'Pilih tanggal',
          style: TextStyle(
            color:
                value != null ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
