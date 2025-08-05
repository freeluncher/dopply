// =============================================================================
// Simplified Patient Model
// =============================================================================

class Patient {
  final int id;
  final int? userId;
  final String name;
  final String email;
  final DateTime? hpht; // Last menstrual period
  final DateTime? birthDate;
  final String? address;
  final String? medicalNote;
  final int? gestationalAge; // Calculated from HPHT
  final String? phoneNumber;
  final int? age;

  const Patient({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    this.hpht,
    this.birthDate,
    this.address,
    this.medicalNote,
    this.gestationalAge,
    this.phoneNumber,
    this.age,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      hpht: json['hpht'] != null ? DateTime.parse(json['hpht']) : null,
      birthDate:
          json['birth_date'] != null
              ? DateTime.parse(json['birth_date'])
              : null,
      address: json['address'],
      medicalNote: json['medical_note'],
      gestationalAge: json['gestational_age'] ?? json['gestational_age_weeks'],
      phoneNumber: json['phone_number'],
      age: json['age'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'hpht': hpht?.toIso8601String(),
      'birth_date': birthDate?.toIso8601String(),
      'address': address,
      'medical_note': medicalNote,
      'gestational_age': gestationalAge,
      'phone_number': phoneNumber,
      'age': age,
    };
  }

  Patient copyWith({
    int? id,
    int? userId,
    String? name,
    String? email,
    DateTime? hpht,
    DateTime? birthDate,
    String? address,
    String? medicalNote,
    int? gestationalAge,
    String? phoneNumber,
    int? age,
  }) {
    return Patient(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      hpht: hpht ?? this.hpht,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      medicalNote: medicalNote ?? this.medicalNote,
      gestationalAge: gestationalAge ?? this.gestationalAge,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
    );
  }

  // Calculate gestational age from HPHT
  int? get calculatedGestationalAge {
    if (hpht == null) return gestationalAge;

    final now = DateTime.now();
    final difference = now.difference(hpht!);
    final weeks = (difference.inDays / 7).floor();

    return weeks > 0 && weeks <= 42 ? weeks : gestationalAge;
  }
}
