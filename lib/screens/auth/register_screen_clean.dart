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
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Password tidak sama', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      final result = await authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (result.isSuccess) {
        _showSnackBar('Registrasi berhasil!');
        if (mounted) {
          context.go('/login');
        }
      } else {
        _showSnackBar(result.errorMessage ?? 'Registrasi gagal', isError: true);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
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
          onPressed: () => context.go('/login'),
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

                // Name Field
                AppInputField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap',
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Nama tidak boleh kosong';
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
                    if (!value!.contains('@')) {
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
                      onTap: () => context.go('/login'),
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
}
