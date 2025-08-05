// =============================================================================
// Simplified Register Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dopply_app/services/auth_service.dart';
import 'package:dopply_app/widgets/common/button.dart';
import 'package:dopply_app/widgets/common/input_field.dart';
import 'package:dopply_app/core/theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'patient';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  int _registerAttempts = 0;
  bool _hasNetworkError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
        action:
            isError && _hasNetworkError
                ? SnackBarAction(
                  label: 'Coba Lagi',
                  textColor: Colors.white,
                  onPressed: _register,
                )
                : null,
      ),
    );
  }

  void _handleRegisterError(String error) {
    // Debug: Print the original error to understand categorization issues
    print('[REGISTER_ERROR] Original error: $error');
    print('[REGISTER_ERROR] Lowercase error: ${error.toLowerCase()}');

    setState(() {
      _hasNetworkError = _isNetworkError(error);
      _errorMessage = _getFriendlyErrorMessage(error);
    });

    print('[REGISTER_ERROR] Is network error: $_hasNetworkError');
    print('[REGISTER_ERROR] Friendly message: $_errorMessage');

    _showSnackBar(_errorMessage!, isError: true);
  }

  bool _isNetworkError(String error) {
    final networkKeywords = [
      'network',
      'connection',
      'timeout',
      'unreachable',
      'socket',
      'internet',
      'dns',
      'host',
    ];

    final lowerError = error.toLowerCase();
    return networkKeywords.any((keyword) => lowerError.contains(keyword));
  }

  String _getFriendlyErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    // Network related errors (check first)
    if (_isNetworkError(error)) {
      return 'Koneksi internet bermasalah. Pastikan Anda terhubung ke internet dan coba lagi.';
    }

    // Email already exists
    if (lowerError.contains('email already exists') ||
        lowerError.contains('email sudah digunakan') ||
        lowerError.contains('email already registered') ||
        lowerError.contains('duplicate email') ||
        lowerError.contains('email taken') ||
        lowerError.contains('user already exists')) {
      return 'Email sudah terdaftar. Silakan gunakan email lain atau masuk dengan akun yang sudah ada.';
    }

    // Validation errors
    if (lowerError.contains('invalid email') ||
        lowerError.contains('email tidak valid') ||
        lowerError.contains('invalid email format') ||
        lowerError.contains('malformed email')) {
      return 'Format email tidak valid. Pastikan email Anda benar.';
    }

    // Password validation errors
    if (lowerError.contains('password too weak') ||
        lowerError.contains('password terlalu lemah') ||
        lowerError.contains('weak password') ||
        lowerError.contains('password must contain') ||
        lowerError.contains('password requirements')) {
      return 'Password terlalu lemah. Gunakan kombinasi huruf, angka, dan simbol minimal 6 karakter.';
    }

    // Name validation errors
    if (lowerError.contains('invalid name') ||
        lowerError.contains('name too short') ||
        lowerError.contains('nama tidak valid')) {
      return 'Nama tidak valid. Pastikan nama lengkap Anda benar.';
    }

    // Server errors
    if (lowerError.contains('500') ||
        lowerError.contains('server error') ||
        lowerError.contains('internal server') ||
        lowerError.contains('service unavailable') ||
        lowerError.contains('server unavailable')) {
      return 'Server sedang mengalami gangguan. Silakan coba lagi dalam beberapa saat.';
    }

    // Rate limiting
    if (lowerError.contains('too many') ||
        lowerError.contains('rate limit') ||
        lowerError.contains('terlalu banyak') ||
        lowerError.contains('too many attempts') ||
        lowerError.contains('rate exceeded')) {
      return 'Terlalu banyak percobaan registrasi. Silakan tunggu beberapa menit sebelum mencoba lagi.';
    }

    // Database/storage errors
    if (lowerError.contains('database') ||
        lowerError.contains('storage') ||
        lowerError.contains('unable to save') ||
        lowerError.contains('failed to create')) {
      return 'Tidak dapat menyimpan data. Silakan coba lagi dalam beberapa saat.';
    }

    // Default friendly message
    return 'Terjadi kesalahan saat registrasi. Silakan periksa data Anda dan coba lagi.';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage =
            'Password dan konfirmasi password tidak sama. Silakan periksa kembali.';
      });
      _showSnackBar(_errorMessage!, isError: true);
      return;
    }

    // Clear previous errors
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasNetworkError = false;
    });

    try {
      _registerAttempts++;
      final authService = ref.read(authServiceProvider);

      final result = await authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Reset register attempts on success
        _registerAttempts = 0;

        _showSnackBar(
          'Registrasi berhasil! Silakan login dengan akun baru Anda.',
        );

        // Small delay for better UX
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          context.go('/login');
        }
      } else {
        _handleRegisterError(result.errorMessage ?? 'Registrasi gagal');
      }
    } catch (e) {
      _handleRegisterError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            try {
              context.go('/login');
            } catch (e) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Title
                Text(
                  'Daftar Akun',
                  style: AppTheme.heading1.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Buat akun baru untuk menggunakan Dopply',
                  style: AppTheme.bodyText.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Error banner
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 20),
                ],

                // Name Field
                AppInputField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap',
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (value!.length < 2) {
                      return 'Nama terlalu pendek';
                    }
                    if (value.length > 50) {
                      return 'Nama terlalu panjang (maksimal 50 karakter)';
                    }
                    // Check for valid name characters
                    if (!RegExp(r'^[a-zA-Z\s\.]+$').hasMatch(value)) {
                      return 'Nama hanya boleh mengandung huruf dan spasi';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Email Field
                AppInputField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'nama@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Email tidak boleh kosong';
                    }
                    // Enhanced email validation
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value!)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Role Selection
                Text(
                  'Peran',
                  style: AppTheme.bodyText.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'patient', child: Text('Pasien')),
                      DropdownMenuItem(value: 'doctor', child: Text('Dokter')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedRole = value!);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Password Field
                AppInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Masukkan password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value!.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    // Enhanced password validation
                    if (!value.contains(RegExp(r'[A-Za-z]'))) {
                      return 'Password harus mengandung huruf';
                    }
                    if (!value.contains(RegExp(r'[0-9]'))) {
                      return 'Password harus mengandung angka';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Confirm Password Field
                AppInputField(
                  controller: _confirmPasswordController,
                  label: 'Konfirmasi Password',
                  hintText: 'Masukkan ulang password',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed:
                        () => setState(
                          () =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                        ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Konfirmasi password tidak boleh kosong';
                    }
                    if (value != _passwordController.text) {
                      return 'Password tidak sama';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // Register Button
                AppButton(
                  text: 'Daftar',
                  onPressed: _register,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: AppTheme.bodyText.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        try {
                          context.go('/login');
                        } catch (e) {
                          _showSnackBar(
                            'Tidak dapat membuka halaman login. Silakan coba lagi.',
                            isError: true,
                          );
                        }
                      },
                      child: Text(
                        'Masuk',
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasNetworkError ? Icons.wifi_off : Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasNetworkError ? 'Masalah Koneksi' : 'Registrasi Gagal',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 18),
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _hasNetworkError = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red[700], fontSize: 13, height: 1.3),
          ),
          if (_hasNetworkError || _registerAttempts > 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_hasNetworkError)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _register,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Coba Lagi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                if (_hasNetworkError && _registerAttempts > 2)
                  const SizedBox(width: 8),
                if (_registerAttempts > 2)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        try {
                          context.go('/login');
                        } catch (e) {
                          _showSnackBar(
                            'Tidak dapat membuka halaman login.',
                            isError: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.login, size: 16),
                      label: const Text('Sudah Punya Akun?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
