// =============================================================================
// Improved Doctor Dashboard - Enhanced UI with All Original Functions
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:dopply_app/services/auth_service.dart';
import 'package:dopply_app/core/storage.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:dopply_app/services/notification_service.dart';
import 'package:dopply_app/widgets/notification_badge.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  String? _doctorPhotoUrl;
  bool _isLoadingProfile = true;
  int _unreadNotificationCount = 0;
  bool _isVerified = true; // Default to true, will be updated from API

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
    _loadUnreadNotificationCount();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final count = await notificationService.getUnreadCount();
      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (e) {
      print('[DoctorDashboard] Error loading notification count: $e');
    }
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoadingProfile = false;
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
          setState(() {
            _doctorPhotoUrl = doctor['photo_url'];
            _isVerified =
                doctor['is_verified'] ?? false; // Capture verification status
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('[DoctorDashboard] Error loading profile: $e');
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Widget _buildDoctorAvatar() {
    if (_isLoadingProfile) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      );
    }

    if (_doctorPhotoUrl != null && _doctorPhotoUrl!.isNotEmpty) {
      // Konstruksi URL lengkap untuk foto
      final fullPhotoUrl =
          _doctorPhotoUrl!.startsWith('http')
              ? _doctorPhotoUrl!
              : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$_doctorPhotoUrl';

      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.network(
                fullPhotoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: const Icon(
                      Icons.medical_services,
                      color: AppTheme.primaryColor,
                      size: 36,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // Fallback ke icon medical_services jika tidak ada foto
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.medical_services,
        color: AppTheme.primaryColor,
        size: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: const Text(
                  'Dashboard Dokter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: false, // Changed to false for left alignment
                titlePadding: const EdgeInsets.only(
                  left: 16,
                  bottom: 16,
                ), // Added left padding
              ),
            ),
            actions: [
              // Notification Badge with improved styling
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: NotificationBadge(
                  unreadCount: _unreadNotificationCount,
                  onTap: () {
                    context.push('/doctor/notifications');
                    // Refresh notification count after returning
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _loadUnreadNotificationCount();
                    });
                  },
                ),
              ),
              // Menu button with improved styling
              Container(
                margin: const EdgeInsets.only(right: 16, left: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    if (value == 'logout') {
                      final authService = ref.read(authServiceProvider);
                      await authService.logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    } else if (value == 'profile') {
                      context.push('/settings');
                    } else if (value == 'notifications') {
                      context.push('/doctor/notifications');
                      // Refresh notification count after returning
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _loadUnreadNotificationCount();
                      });
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'notifications',
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.blue,
                                  ),
                                  if (_unreadNotificationCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Notifikasi ${_unreadNotificationCount > 0 ? '($_unreadNotificationCount)' : ''}',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, color: Colors.green),
                              SizedBox(width: 12),
                              Text('Profil & Pengaturan'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                ),
              ),
            ],
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section with Time-based Greeting
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildDoctorAvatar(),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: AppTheme.heading2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Siap melayani pasien hari ini',
                                style: AppTheme.bodyText.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isVerified
                                          ? AppTheme.primaryColor.withOpacity(
                                            0.1,
                                          )
                                          : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        _isVerified
                                            ? AppTheme.primaryColor.withOpacity(
                                              0.2,
                                            )
                                            : Colors.orange.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isVerified
                                          ? Icons.verified_user
                                          : Icons.pending,
                                      size: 16,
                                      color:
                                          _isVerified
                                              ? AppTheme.primaryColor
                                              : Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isVerified
                                          ? 'Dokter Terverifikasi'
                                          : 'Menunggu Verifikasi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            _isVerified
                                                ? AppTheme.primaryColor
                                                : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Verification Status Banner for Unverified Doctors
                  if (!_isVerified) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Akun Menunggu Verifikasi',
                                      style: AppTheme.heading3.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Akun Anda sedang dalam proses verifikasi oleh admin.',
                                      style: AppTheme.bodyText.copyWith(
                                        color: Colors.orange[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sementara Menunggu Verifikasi:',
                                  style: AppTheme.heading3.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildVerificationStatusItem(
                                  icon: Icons.edit_outlined,
                                  text: 'Anda dapat mengatur profil dan foto',
                                  isAllowed: true,
                                ),
                                const SizedBox(height: 8),
                                _buildVerificationStatusItem(
                                  icon: Icons.monitor_heart_outlined,
                                  text: 'Monitoring pasien terbatas',
                                  isAllowed: false,
                                ),
                                const SizedBox(height: 8),
                                _buildVerificationStatusItem(
                                  icon: Icons.notifications_outlined,
                                  text: 'Notifikasi sistem tersedia',
                                  isAllowed: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quick Actions Title
                  Text(
                    'Aksi Cepat',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Main Feature Cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildEnhancedFeatureCard(
                        icon: Icons.monitor_heart,
                        title: 'Monitoring',
                        subtitle: 'Pantau kondisi pasien\nsecara real-time',
                        color: Colors.green,
                        isAvailable:
                            _isVerified, // Only available for verified doctors
                        onTap: () => context.go('/monitoring'),
                      ),
                      _buildEnhancedFeatureCard(
                        icon: Icons.history,
                        title: 'Riwayat Monitoring',
                        subtitle: 'Lihat data monitoring\nsebelumnya',
                        color: Colors.blue,
                        isAvailable:
                            _isVerified, // Only available for verified doctors
                        onTap: () => context.go('/history'),
                      ),
                      _buildEnhancedFeatureCard(
                        icon: Icons.notifications_active,
                        title: 'Notifikasi',
                        subtitle: 'Pemberitahuan penting\nuntuk dokter',
                        color: Colors.orange,
                        isAvailable: true,
                        onTap: () => context.push('/doctor/notifications'),
                      ),
                      _buildEnhancedFeatureCard(
                        icon: Icons.settings,
                        title: 'Pengaturan',
                        subtitle: 'Atur profil dan preferensi\ndokter',
                        color: Colors.purple,
                        isAvailable: true,
                        onTap: () => context.go('/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Coming Soon Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.schedule,
                                color: Colors.orange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fitur Akan Segera Hadir',
                                    style: AppTheme.heading3.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    'Fitur lanjutan yang sedang dalam pengembangan',
                                    style: AppTheme.caption.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Coming Soon Items
                        Column(
                          children: [
                            _buildEnhancedComingSoonItem(
                              icon: Icons.video_call,
                              title: 'Telemedicine',
                              subtitle: 'Konsultasi jarak jauh dengan pasien',
                              progress: 0.7,
                            ),
                            const SizedBox(height: 12),
                            _buildEnhancedComingSoonItem(
                              icon: Icons.science,
                              title: 'Integrasi Lab',
                              subtitle: 'Hasil lab otomatis masuk ke sistem',
                              progress: 0.4,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi, Dokter';
    if (hour < 17) return 'Selamat Siang, Dokter';
    return 'Selamat Malam, Dokter';
  }

  Widget _buildEnhancedFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isAvailable,
    VoidCallback? onTap,
  }) {
    // Show notification count on the notification card
    final showNotificationBadge =
        title == 'Notifikasi' && _unreadNotificationCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Container with Animation Effect and Badge
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isAvailable
                                ? color.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isAvailable ? color : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                    // Notification badge for notification card
                    if (showNotificationBadge)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            _unreadNotificationCount > 99
                                ? '99+'
                                : _unreadNotificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title with notification indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTheme.heading3.copyWith(
                          color:
                              isAvailable ? Colors.grey[800] : Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showNotificationBadge) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // Subtitle
                Flexible(
                  child: Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: isAvailable ? Colors.grey[600] : Colors.grey[400],
                      height: 1.2,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Coming Soon Badge
                if (!isAvailable) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          // Show different colors based on context
                          (title == 'Monitoring' ||
                                      title == 'Riwayat Monitoring') &&
                                  !_isVerified
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          (title == 'Monitoring' ||
                                      title == 'Riwayat Monitoring') &&
                                  !_isVerified
                              ? Colors.orange.withOpacity(0.05)
                              : Colors.orange.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (title == 'Monitoring' ||
                                        title == 'Riwayat Monitoring') &&
                                    !_isVerified
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      (title == 'Monitoring' ||
                                  title == 'Riwayat Monitoring') &&
                              !_isVerified
                          ? 'Perlu Verifikasi'
                          : 'Segera Hadir',
                      style: TextStyle(
                        color:
                            (title == 'Monitoring' ||
                                        title == 'Riwayat Monitoring') &&
                                    !_isVerified
                                ? Colors.orange
                                : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Available badge for notification card
                if (isAvailable && title == 'Notifikasi') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.1),
                          Colors.green.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Tersedia',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedComingSoonItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.orange, size: 20),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.heading3.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: AppTheme.caption.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 8),

                // Progress Bar
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange,
                            Colors.orange.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusItem({
    required IconData icon,
    required String text,
    required bool isAllowed,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isAllowed ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isAllowed ? Colors.grey[700] : Colors.grey[500],
              fontWeight: isAllowed ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        Icon(
          isAllowed ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isAllowed ? Colors.green : Colors.grey,
        ),
      ],
    );
  }
}
