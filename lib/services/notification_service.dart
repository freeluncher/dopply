import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dopply_app/models/monitoring_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopply_app/models/notification.dart';
import 'package:dopply_app/core/api_client.dart';
import 'package:dopply_app/core/storage.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  // Get JWT token from secure storage using StorageService
  Future<String?> _getToken() async {
    return await StorageService.getToken();
  }

  // Get notifications for doctor (unified method)
  Future<List<NotificationItem>> getNotifications({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/monitoring/notifications?skip=$skip&limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Handle different response structures
        List<dynamic> notificationsList;
        if (jsonResponse is Map && jsonResponse.containsKey('notifications')) {
          notificationsList = jsonResponse['notifications'] as List;
        } else if (jsonResponse is List) {
          notificationsList = jsonResponse;
        } else {
          notificationsList = [];
        }

        return notificationsList
            .map(
              (notification) => NotificationItem.fromJson(
                notification as Map<String, dynamic>,
              ),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else {
        throw Exception(
          'Failed to fetch notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  // Get monitoring notifications (legacy method for backward compatibility)
  Future<List<MonitoringNotification>> getMonitoringNotifications({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/monitoring/notifications?skip=$skip&limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        List<dynamic> notificationsList;
        if (jsonResponse is Map && jsonResponse.containsKey('notifications')) {
          notificationsList = jsonResponse['notifications'] as List;
        } else if (jsonResponse is List) {
          notificationsList = jsonResponse;
        } else {
          notificationsList = [];
        }

        return notificationsList
            .map(
              (notification) => MonitoringNotification.fromJson(
                notification as Map<String, dynamic>,
              ),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else {
        throw Exception(
          'Failed to fetch monitoring notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching monitoring notifications: $e');
      throw Exception('Failed to fetch monitoring notifications: $e');
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/monitoring/notifications/read/$notificationId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Notification not found');
      } else {
        throw Exception(
          'Failed to mark notification as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/monitoring/notifications/read-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else {
        throw Exception(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications(
        limit: 100,
      ); // Get more to count properly
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Static methods for backward compatibility
  static Future<List<MonitoringNotification>> fetchNotifications(
    String jwt, {
    int skip = 0,
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/monitoring/notifications?skip=$skip&limit=$limit',
      ),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }

    final jsonResponse = json.decode(response.body);
    List<dynamic> notifList;
    if (jsonResponse is Map && jsonResponse.containsKey('notifications')) {
      notifList = jsonResponse['notifications'] as List;
    } else if (jsonResponse is List) {
      notifList = jsonResponse;
    } else {
      notifList = [];
    }

    return notifList.map((n) => MonitoringNotification.fromJson(n)).toList();
  }

  static Future<bool> markNotificationRead(
    String jwt,
    int notificationId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/monitoring/notifications/read/$notificationId',
      ),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
    );
    return response.statusCode == 200;
  }
}
