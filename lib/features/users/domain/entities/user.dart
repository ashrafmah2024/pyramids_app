import 'package:equatable/equatable.dart';
import 'user_role.dart';
import 'user_status.dart';

class User extends Equatable {
  final String id;
  final String fullName;
  final String username;
  final String? passwordHash;
  final String email;
  final String? phoneNumber;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final String? lastLoginDevice;
  final Map<String, dynamic>? lastLoginLocation;

  const User({
    required this.id,
    required this.fullName,
    required this.username,
    this.passwordHash,
    required this.email,
    this.phoneNumber,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.lastLoginIp,
    this.lastLoginDevice,
    this.lastLoginLocation,
  });

  @override
  List<Object?> get props => [
        id,
        fullName,
        username,
        email,
        phoneNumber,
        role,
        status,
        createdAt,
        updatedAt,
        lastLoginAt,
      ];

  User copyWith({
    String? id,
    String? fullName,
    String? username,
    String? passwordHash,
    String? email,
    String? phoneNumber,
    UserRole? role,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? lastLoginIp,
    String? lastLoginDevice,
    Map<String, dynamic>? lastLoginLocation,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      lastLoginDevice: lastLoginDevice ?? this.lastLoginDevice,
      lastLoginLocation: lastLoginLocation ?? this.lastLoginLocation,
    );
  }
}
