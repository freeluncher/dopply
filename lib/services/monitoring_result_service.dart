import 'package:dopply_app/models/monitoring.dart';
import 'package:dopply_app/core/api_client.dart';

class MonitoringResultService {
  static Future<List<Map<String, dynamic>>>
  fetchPatientMonitoringResults() async {
    try {
      final response = await ApiClient().dio.get('/monitoring/history');
      final data = response.data;
      if (data != null && data is Map && data['results'] is List) {
        return List<Map<String, dynamic>>.from(data['results']);
      }
    } catch (e) {
      // Handle error
    }
    return [];
  }
}
