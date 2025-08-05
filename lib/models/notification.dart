// =============================================================================
// Simplified Notification Model
// =============================================================================

class NotificationItem {
  final int id;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final int? recordId;
  final String? type; // 'monitoring_shared', 'patient_added', etc.
  final Map<String, dynamic>? metadata;

  const NotificationItem({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.recordId,
    this.type,
    this.metadata,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      message: json['message'] ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      isRead: json['is_read'] ?? false,
      recordId: json['record_id'],
      type: json['type'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'record_id': recordId,
      'type': type,
      'metadata': metadata,
    };
  }

  NotificationItem copyWith({
    int? id,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    int? recordId,
    String? type,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      recordId: recordId ?? this.recordId,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
