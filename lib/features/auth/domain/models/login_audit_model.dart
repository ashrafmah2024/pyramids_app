import 'dart:convert';

class LoginAuditModel {
  final String userId;
  final DateTime createdAt;
  final String? ip;
  final String? deviceId;
  final String platform; // android / ios
  final String? deviceModel;
  final String? appVersion;
  final String? osVersion;
  final String? pushToken;
  final Map<String, dynamic>? location; // { lat, lng, accuracy }
  final Map<String, dynamic>? extra; // optional

  const LoginAuditModel({
    required this.userId,
    required this.createdAt,
    required this.platform,
    this.ip,
    this.deviceId,
    this.deviceModel,
    this.appVersion,
    this.osVersion,
    this.pushToken,
    this.location,
    this.extra,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'ip': ip,
      'device_id': deviceId,
      'platform': platform,
      'device_model': deviceModel,
      'app_version': appVersion,
      'os_version': osVersion,
      'push_token': pushToken,
      'location': location == null ? null : jsonDecode(jsonEncode(location)),
      'extra': extra == null ? null : jsonDecode(jsonEncode(extra)),
    }..removeWhere((key, value) => value == null);
  }
}
