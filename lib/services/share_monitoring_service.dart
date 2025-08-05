import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dopply_app/core/api_client.dart';

class ShareMonitoringService {
  static Future<bool> shareMonitoring({
    required String jwt,
    required int recordId,
    required int doctorId,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/monitoring/share'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'record_id': recordId,
        'doctor_id': doctorId,
        'notes': notes ?? '',
      }),
    );
    return response.statusCode == 200;
  }
}
