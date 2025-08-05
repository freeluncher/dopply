import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dopply_app/services/admin_service.dart';
import 'package:dopply_app/core/theme.dart';
import 'package:dopply_app/core/api_client.dart';

class DoctorVerificationScreen extends ConsumerStatefulWidget {
  const DoctorVerificationScreen({super.key});

  @override
  ConsumerState<DoctorVerificationScreen> createState() =>
      _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState
    extends ConsumerState<DoctorVerificationScreen>
    with SingleTickerProviderStateMixin {
  List<DoctorForVerification> _allDoctors = [];
  List<DoctorForVerification> _unverifiedDoctors = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminService = ref.read(adminServiceProvider);
      final allDoctors = await adminService.getAllDoctors();

      setState(() {
        _allDoctors = allDoctors;
        _unverifiedDoctors =
            allDoctors.where((doctor) => !doctor.isVerified).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyDoctor(DoctorForVerification doctor) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final adminService = ref.read(adminServiceProvider);
      final success = await adminService.verifyDoctor(doctor.id);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dokter ${doctor.name} berhasil diverifikasi'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data
          _loadDoctors();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memverifikasi dokter'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDoctorDetails(DoctorForVerification doctor) {
    showDialog(
      context: context,
      builder:
          (context) => _DoctorDetailsDialog(
            doctor: doctor,
            onVerify:
                doctor.isVerified
                    ? null
                    : () {
                      Navigator.of(context).pop();
                      _verifyDoctor(doctor);
                    },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
          tooltip: 'Kembali',
        ),
        title: const Text('Verifikasi Dokter'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true, // Make tabs scrollable to prevent overflow
          tabs: [
            Tab(
              text: 'Menunggu (${_unverifiedDoctors.length})',
              icon: const Icon(Icons.pending),
            ),
            Tab(
              text: 'Semua (${_allDoctors.length})',
              icon: const Icon(Icons.people),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDoctors,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoctorList(_unverifiedDoctors, showOnlyUnverified: true),
          _buildDoctorList(_allDoctors, showOnlyUnverified: false),
        ],
      ),
    );
  }

  Widget _buildDoctorList(
    List<DoctorForVerification> doctors, {
    required bool showOnlyUnverified,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Terjadi kesalahan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDoctors,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showOnlyUnverified
                  ? Icons.check_circle_outline
                  : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              showOnlyUnverified
                  ? 'Tidak ada dokter yang menunggu verifikasi'
                  : 'Tidak ada dokter terdaftar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              showOnlyUnverified
                  ? 'Semua dokter sudah diverifikasi'
                  : 'Belum ada dokter yang mendaftar',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDoctors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return _buildDoctorCard(doctor);
        },
      ),
    );
  }

  Widget _buildDoctorCard(DoctorForVerification doctor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDoctorDetails(doctor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Row(
            children: [
              // Doctor Avatar
              CircleAvatar(
                radius: 25, // Reduced radius
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage:
                    doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                        ? NetworkImage(
                          doctor.photoUrl!.startsWith('http')
                              ? doctor.photoUrl!
                              : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}${doctor.photoUrl}',
                        )
                        : null,
                child:
                    doctor.photoUrl == null || doctor.photoUrl!.isEmpty
                        ? Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                          size: 25, // Reduced icon size
                        )
                        : null,
              ),

              const SizedBox(width: 12), // Reduced spacing
              // Doctor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Prevent overflow
                  children: [
                    Text(
                      doctor.name,
                      style: AppTheme.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // Reduced font size
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      doctor.email,
                      style: AppTheme.bodyText.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12, // Reduced font size
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (doctor.specialization != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Spesialisasi: ${doctor.specialization}',
                        style: AppTheme.caption.copyWith(
                          color: Colors.grey[500],
                          fontSize: 10, // Reduced font size
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6), // Reduced spacing
                    Row(
                      children: [
                        Flexible(
                          // Make status badge flexible
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // Reduced padding
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  doctor.isVerified
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                8,
                              ), // Reduced radius
                            ),
                            child: Text(
                              doctor.statusText,
                              style: TextStyle(
                                color:
                                    doctor.isVerified
                                        ? Colors.green
                                        : Colors.orange,
                                fontSize: 9, // Reduced font size
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          // Make time text flexible
                          child: Text(
                            doctor.registrationTimeAgo,
                            style: AppTheme.caption.copyWith(
                              color: Colors.grey[500],
                              fontSize: 10, // Reduced font size
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Button
              if (!doctor.isVerified) ...[
                const SizedBox(width: 4), // Reduced spacing
                IconButton(
                  onPressed: () => _verifyDoctor(doctor),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Verifikasi Dokter',
                  iconSize: 20, // Reduced icon size
                  padding: const EdgeInsets.all(4), // Reduced padding
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.verified, color: Colors.green, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorDetailsDialog extends StatelessWidget {
  final DoctorForVerification doctor;
  final VoidCallback? onVerify;

  const _DoctorDetailsDialog({required this.doctor, this.onVerify});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Limit height
          maxWidth: MediaQuery.of(context).size.width * 0.9, // Limit width
        ),
        child: SingleChildScrollView(
          // Make dialog scrollable
          child: Padding(
            padding: const EdgeInsets.all(20), // Reduced padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25, // Reduced radius
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage:
                          doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                              ? NetworkImage(
                                doctor.photoUrl!.startsWith('http')
                                    ? doctor.photoUrl!
                                    : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}${doctor.photoUrl}',
                              )
                              : null,
                      child:
                          doctor.photoUrl == null || doctor.photoUrl!.isEmpty
                              ? Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                                size: 25, // Reduced icon size
                              )
                              : null,
                    ),
                    const SizedBox(width: 12), // Reduced spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor.name,
                            style: AppTheme.heading2.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18, // Reduced font size
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // Reduced padding
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  doctor.isVerified
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                8,
                              ), // Reduced radius
                            ),
                            child: Text(
                              doctor.statusText,
                              style: TextStyle(
                                color:
                                    doctor.isVerified
                                        ? Colors.green
                                        : Colors.orange,
                                fontSize: 11, // Reduced font size
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20), // Reduced spacing
                // Details
                _buildDetailRow('Email', doctor.email),
                if (doctor.phoneNumber != null)
                  _buildDetailRow('Telepon', doctor.phoneNumber!),
                if (doctor.specialization != null)
                  _buildDetailRow('Spesialisasi', doctor.specialization!),
                if (doctor.licenseNumber != null)
                  _buildDetailRow('No. Lisensi', doctor.licenseNumber!),
                _buildDetailRow('Tanggal Daftar', doctor.registrationTimeAgo),

                const SizedBox(height: 20), // Reduced spacing
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                    if (onVerify != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: onVerify,
                        icon: const Icon(
                          Icons.check_circle,
                          size: 18,
                        ), // Reduced icon size
                        label: const Text('Verifikasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, // Reduced padding
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // Reduced spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90, // Reduced width
            child: Text(
              label,
              style: AppTheme.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 12, // Reduced font size
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyText.copyWith(
                fontSize: 12,
              ), // Reduced font size
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
