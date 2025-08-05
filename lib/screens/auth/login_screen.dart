// =============================================================================
// Simplified Login Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:dopply_app/services/auth_service.dart';
import 'package:dopply_app/widgets/common/button.dart';
import 'package:dopply_app/widgets/common/input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _loginAttempts = 0;
  bool _hasNetworkError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Clear previous errors
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasNetworkError = false;
    });

    try {
      _loginAttempts++;
      final authService = ref.read(authServiceProvider);
      final result = await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.isSuccess && result.user != null) {
        // Reset login attempts on success
        _loginAttempts = 0;

        // Set user ke provider agar state global update
        ref.read(currentUserProvider.notifier).setUser(result.user!);
        final user = result.user!;

        // Show success feedback before navigation
        _showSuccessMessage('Login berhasil! Selamat datang, ${user.name}');

        // Small delay for better UX
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        // Navigate based on role
        switch (user.role) {
          case 'patient':
            context.go('/patient');
            break;
          case 'doctor':
            context.go('/doctor');
            break;
          case 'admin':
            context.go('/admin');
            break;
          default:
            context.go('/patient');
        }
      } else {
        _handleLoginError(result.errorMessage ?? 'Login gagal');
      }
    } catch (e) {
      _handleLoginError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLoginError(String error) {
    // Debug: Print the original error to understand categorization issues
    print('[LOGIN_ERROR] Original error: $error');
    print('[LOGIN_ERROR] Lowercase error: ${error.toLowerCase()}');

    setState(() {
      _hasNetworkError = _isNetworkError(error);
      _errorMessage = _getFriendlyErrorMessage(error);
    });

    print('[LOGIN_ERROR] Is network error: $_hasNetworkError');
    print('[LOGIN_ERROR] Friendly message: $_errorMessage');

    _showErrorMessage(_errorMessage!);
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

    // Authentication errors (check before verification errors)
    if (lowerError.contains('unauthorized') ||
        lowerError.contains('invalid credentials') ||
        lowerError.contains('wrong password') ||
        lowerError.contains('password salah') ||
        lowerError.contains('email atau password salah') ||
        lowerError.contains('login failed') ||
        lowerError.contains('authentication failed') ||
        lowerError.contains('invalid login') ||
        lowerError.contains('incorrect password') ||
        lowerError.contains('invalid email or password')) {
      return 'Email atau password yang Anda masukkan salah. Silakan periksa kembali.';
    }

    // Account not found
    if (lowerError.contains('user not found') ||
        lowerError.contains('account not found') ||
        lowerError.contains('akun tidak ditemukan') ||
        lowerError.contains('email not found') ||
        lowerError.contains('no user found')) {
      return 'Akun dengan email tersebut tidak ditemukan. Pastikan email sudah benar atau daftar terlebih dahulu.';
    }

    // Email verification needed (be more specific)
    if ((lowerError.contains('email') && lowerError.contains('verification')) ||
        (lowerError.contains('email') && lowerError.contains('verify')) ||
        lowerError.contains('unverified email') ||
        lowerError.contains('email not verified') ||
        lowerError.contains('please verify your email') ||
        lowerError.contains('email belum diverifikasi')) {
      return 'Email Anda belum diverifikasi. Silakan cek email dan klik link verifikasi.';
    }

    // Account locked/suspended
    if (lowerError.contains('locked') ||
        lowerError.contains('suspended') ||
        lowerError.contains('blocked') ||
        lowerError.contains('disabled') ||
        lowerError.contains('account suspended') ||
        lowerError.contains('account locked')) {
      return 'Akun Anda sedang dalam peninjauan atau diblokir. Hubungi admin untuk bantuan.';
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
      return 'Terlalu banyak percobaan login. Silakan tunggu beberapa menit sebelum mencoba lagi.';
    }

    // Default friendly message
    return 'Terjadi kesalahan saat login. Silakan periksa koneksi internet dan coba lagi.';
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action:
            _hasNetworkError
                ? SnackBarAction(
                  label: 'Coba Lagi',
                  textColor: Colors.white,
                  onPressed: _handleLogin,
                )
                : null,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Logo and title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/icon-dopply-transparent.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dopply',
                        style: AppTheme.heading1.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fetal Heart Rate Monitoring',
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Login form
                Text('Masuk ke Akun Anda', style: AppTheme.heading2),
                const SizedBox(height: 24),

                // Error banner
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],

                // Email field
                AppInputField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Masukkan email Anda',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                AppInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Masukkan password Anda',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Login button
                AppButton(
                  text: 'Masuk',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        try {
                          context.push('/register');
                        } catch (e) {
                          _showErrorMessage(
                            'Tidak dapat membuka halaman pendaftaran. Silakan coba lagi.',
                          );
                        }
                      },
                      child: Text(
                        'Daftar',
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
                  _hasNetworkError ? 'Masalah Koneksi' : 'Login Gagal',
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
          if (_hasNetworkError || _loginAttempts > 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_hasNetworkError)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleLogin,
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
                if (_hasNetworkError && _loginAttempts > 2)
                  const SizedBox(width: 8),
                if (_loginAttempts > 2)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        try {
                          context.push('/forgot-password');
                        } catch (e) {
                          _showErrorMessage(
                            'Tidak dapat membuka halaman reset password.',
                          );
                        }
                      },
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text('Lupa Password?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange.withOpacity(0.5)),
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
