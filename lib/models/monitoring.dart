// =============================================================================
// Simplified Monitoring Model
// =============================================================================

// Real-time BPM data point for monitoring
class BpmDataPoint {
  final DateTime timestamp;
  final int bpm;

  const BpmDataPoint({required this.timestamp, required this.bpm});

  factory BpmDataPoint.fromJson(Map<String, dynamic> json) {
    return BpmDataPoint(
      timestamp: DateTime.parse(json['timestamp']),
      bpm: json['bpm'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'timestamp': timestamp.toIso8601String(), 'bpm': bpm};
  }
}

class MonitoringResult {
  final int id;
  final List<int> bpmData;
  final String classification; // 'normal', 'bradikardia', 'takikardia'
  final DateTime createdAt;
  final String? notes;
  final String? doctorNotes;
  final int? gestationalAge;
  final int? patientId;
  final String? patientName;
  final int? doctorId;
  final String? doctorName;
  final double? averageBpm;
  final int? maxBpm;
  final int? minBpm;

  const MonitoringResult({
    required this.id,
    required this.bpmData,
    required this.classification,
    required this.createdAt,
    this.notes,
    this.doctorNotes,
    this.gestationalAge,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
    this.averageBpm,
    this.maxBpm,
    this.minBpm,
  });

  factory MonitoringResult.fromJson(Map<String, dynamic> json) {
    // Handle bpm_data as either List<int> or String
    List<int> parsedBpmData = [];
    if (json['bpm_data'] is List) {
      parsedBpmData = List<int>.from(json['bpm_data']);
    } else if (json['bpm_data'] is String) {
      try {
        final String bpmString = json['bpm_data'];
        // Remove brackets and split by comma
        final String cleanString = bpmString
            .replaceAll('[', '')
            .replaceAll(']', '');
        parsedBpmData =
            cleanString
                .split(',')
                .where((s) => s.trim().isNotEmpty)
                .map((s) => int.tryParse(s.trim()) ?? 0)
                .toList();
      } catch (e) {
        print('[MonitoringResult] Error parsing bpm_data string: $e');
      }
    }

    return MonitoringResult(
      id: json['id'] ?? 0,
      bpmData: parsedBpmData,
      classification: json['classification'] ?? 'unknown',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      notes: json['notes'],
      doctorNotes: json['doctor_notes'],
      gestationalAge: json['gestational_age'],
      patientId: json['patient_id'],
      patientName: json['patient_name'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'],
      averageBpm: json['average_bpm']?.toDouble(),
      maxBpm: json['max_bpm'],
      minBpm: json['min_bpm'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bpm_data': bpmData,
      'classification': classification,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'doctor_notes': doctorNotes,
      'gestational_age': gestationalAge,
      'patient_id': patientId,
      'patient_name': patientName,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'average_bpm': averageBpm,
      'max_bpm': maxBpm,
      'min_bpm': minBpm,
    };
  }

  MonitoringResult copyWith({
    int? id,
    List<int>? bpmData,
    String? classification,
    DateTime? createdAt,
    String? notes,
    String? doctorNotes,
    int? gestationalAge,
    int? patientId,
    String? patientName,
    int? doctorId,
    String? doctorName,
    double? averageBpm,
    int? maxBpm,
    int? minBpm,
  }) {
    return MonitoringResult(
      id: id ?? this.id,
      bpmData: bpmData ?? this.bpmData,
      classification: classification ?? this.classification,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      gestationalAge: gestationalAge ?? this.gestationalAge,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      averageBpm: averageBpm ?? this.averageBpm,
      maxBpm: maxBpm ?? this.maxBpm,
      minBpm: minBpm ?? this.minBpm,
    );
  }

  // Helper getters
  bool get isNormal => classification.toLowerCase() == 'normal';
  bool get isBradikardia => classification.toLowerCase() == 'bradikardia';
  bool get isTakikardia => classification.toLowerCase() == 'takikardia';

  double get calculatedAverageBpm {
    if (averageBpm != null) return averageBpm!;
    if (bpmData.isEmpty) return 0.0;
    return bpmData.reduce((a, b) => a + b) / bpmData.length;
  }

  int get calculatedMaxBpm {
    if (maxBpm != null) return maxBpm!;
    if (bpmData.isEmpty) return 0;
    return bpmData.reduce((a, b) => a > b ? a : b);
  }

  int get calculatedMinBpm {
    if (minBpm != null) return minBpm!;
    if (bpmData.isEmpty) return 0;
    return bpmData.reduce((a, b) => a < b ? a : b);
  }
}
