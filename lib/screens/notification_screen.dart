import 'package:flutter/material.dart';
import 'package:dopply_app/models/monitoring_notification.dart';
import 'package:dopply_app/services/notification_service.dart';
import 'package:dopply_app/widgets/notification_badge.dart';
import 'package:dopply_app/screens/notification_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String jwt;
  const NotificationScreen({super.key, required this.jwt});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<MonitoringNotification>> _futureNotifications;

  @override
  void initState() {
    super.initState();
    _futureNotifications = NotificationService.fetchNotifications(widget.jwt);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureNotifications = NotificationService.fetchNotifications(widget.jwt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MonitoringNotification>>(
      future: _futureNotifications,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi Monitoring'),
            actions: [
              NotificationBadge(unreadCount: unreadCount, onTap: _refresh),
            ],
          ),
          body: _buildBody(snapshot, notifications),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<MonitoringNotification>> snapshot,
    List<MonitoringNotification> notifications,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return const Center(child: Text('Gagal memuat notifikasi'));
    }
    if (notifications.isEmpty) {
      return const Center(child: Text('Tidak ada notifikasi'));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return ListTile(
            leading: Icon(
              notif.isRead ? Icons.notifications : Icons.notifications_active,
              color: notif.isRead ? Colors.grey : Colors.blue,
            ),
            title: Text(notif.message),
            subtitle: Text('${notif.fromPatientName} • ${notif.createdAt}'),
            trailing:
                notif.isRead
                    ? null
                    : const Icon(Icons.fiber_new, color: Colors.red),
            onTap: () async {
              final success = await NotificationService.markNotificationRead(
                widget.jwt,
                notif.id,
              );
              if (success) _refresh();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => NotificationDetailScreen(recordId: notif.recordId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
