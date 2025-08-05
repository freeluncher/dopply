import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:dopply_app/core/api_client.dart';
import 'package:image_picker/image_picker.dart';

class EditDoctorProfileScreen extends ConsumerStatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  ConsumerState<EditDoctorProfileScreen> createState() =>
      _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState
    extends ConsumerState<EditDoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _errorMsg;

  // Profile fields
  int? doctorId;
  int? userId;
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController specializationController = TextEditingController();
  String? _currentPhotoUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    specializationController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMsg = 'Token tidak ditemukan. Silakan login ulang.';
        });
        return;
      }

      final url = '${ApiConfig.baseUrl}/doctor/profile';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final respJson = jsonDecode(response.body);
        if (respJson['status'] == 'success' && respJson['doctor'] != null) {
          final doctor = respJson['doctor'];
          doctorId = doctor['id'];
          // userId tetap bisa diambil dari local storage jika perlu
          setState(() {
            nameController.text = doctor['name'] ?? '';
            emailController.text = doctor['email'] ?? '';
            specializationController.text = doctor['specialization'] ?? '';
            _currentPhotoUrl = doctor['photo_url'] ?? '';
          });
        } else {
          setState(() {
            _errorMsg = respJson['message'] ?? 'Gagal memuat data dokter';
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _errorMsg = 'Sesi login habis atau tidak valid. Silakan login ulang.';
        });
      } else {
        final respJson = jsonDecode(response.body);
        setState(() {
          _errorMsg = respJson['message'] ?? 'Gagal memuat data dokter';
        });
      }
    } catch (e) {
      print('[EditDoctorProfile] Error loading doctor data: $e');
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

      final url = '${ApiConfig.baseUrl}/doctor/profile/photo';
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
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMsg = 'Token tidak ditemukan. Silakan login ulang.';
        });
        return;
      }

      final url = '${ApiConfig.baseUrl}/doctor/profile';

      // Hanya kirim field yang tidak kosong
      final Map<String, dynamic> bodyData = {};

      if (nameController.text.trim().isNotEmpty) {
        bodyData['name'] = nameController.text.trim();
      }
      if (emailController.text.trim().isNotEmpty) {
        bodyData['email'] = emailController.text.trim();
      }
      if (specializationController.text.trim().isNotEmpty) {
        bodyData['specialization'] = specializationController.text.trim();
      }
      if (_currentPhotoUrl != null && _currentPhotoUrl!.trim().isNotEmpty) {
        bodyData['photo_url'] = _currentPhotoUrl!.trim();
      }

      final body = jsonEncode(bodyData);

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
        // Update local storage dengan data baru
        if (respJson['doctor'] != null) {
          final currentUserData = await StorageService.getUserData();
          if (currentUserData != null) {
            final currentUser = jsonDecode(currentUserData);
            // Merge data baru dengan data yang ada
            final updatedUser = Map<String, dynamic>.from(currentUser);
            updatedUser.addAll(respJson['doctor']);
            await StorageService.saveUserData(jsonEncode(updatedUser));
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profil dokter berhasil diperbarui!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Kembali ke dashboard dokter
          context.go('/doctor');
        }
      } else {
        setState(() {
          _errorMsg = respJson['message'] ?? 'Gagal update profil dokter';
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
        title: const Text('Edit Profil Dokter'),
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
              context.go('/doctor');
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
                      'Memuat data dokter...',
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
                                    Icons.medical_services,
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
                                        'Profil Dokter',
                                        style: AppTheme.heading2,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Perbarui informasi profil Anda',
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
                                  'Informasi Profil',
                                  style: AppTheme.heading3,
                                ),
                                const SizedBox(height: 16),

                                // Name Field
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap',
                                    hintText: 'Masukkan nama lengkap dokter',
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

                                // Specialization Field
                                TextFormField(
                                  controller: specializationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Spesialisasi',
                                    hintText: 'Masukkan spesialisasi dokter',
                                    prefixIcon: Icon(
                                      Icons.local_hospital_outlined,
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Spesialisasi wajib diisi'
                                              : null,
                                ),
                                const SizedBox(height: 16),

                                // Photo Upload Section
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
                                          'Foto Profil',
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
                                          'Simpan Profil',
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
