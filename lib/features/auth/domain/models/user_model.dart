class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final String role;
  final DateTime? emailConfirmedAt;
  final DateTime? lastSignInAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phoneNumber,
    required this.role,
    this.emailConfirmedAt,
    this.lastSignInAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      role: json['role'] as String? ?? 'user',
      emailConfirmedAt: json['email_confirmed_at'] != null
          ? DateTime.parse(json['email_confirmed_at'] as String)
          : null,
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      'email_confirmed_at': emailConfirmedAt?.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    DateTime? emailConfirmedAt,
    DateTime? lastSignInAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
