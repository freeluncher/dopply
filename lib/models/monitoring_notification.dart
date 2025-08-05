class MonitoringNotification {
  final int id;
  final String fromPatientName;
  final int recordId;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  MonitoringNotification({
    required this.id,
    required this.fromPatientName,
    required this.recordId,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory MonitoringNotification.fromJson(Map<String, dynamic> json) {
    return MonitoringNotification(
      id: json['id'],
      fromPatientName: json['from_patient_name'],
      recordId: json['record_id'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'],
    );
  }
}
