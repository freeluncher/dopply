// =============================================================================
// Simplified User Model
// =============================================================================

class User {
  final int id;
  final String name;
  final String email;
  final String role; // 'patient', 'doctor', 'admin'
  final bool? isVerified; // For doctors only
  final String? photoUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isVerified,
    this.photoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'patient',
      isVerified: json['is_verified'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_verified': isVerified,
      'photo_url': photoUrl,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    bool? isVerified,
    String? photoUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  bool get isPatient => role == 'patient';
  bool get isDoctor => role == 'doctor';
  bool get isAdmin => role == 'admin';
}
