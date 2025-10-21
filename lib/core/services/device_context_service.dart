import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pyramids/core/constants/app_constants.dart';
import 'package:pyramids/features/auth/domain/models/login_audit_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceContextService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _kDeviceIdKey = 'device_id';

  static Future<String?> _getPublicIp() async {
    try {
      final resp = await http.get(Uri.parse(AppConstants.publicIpUrl)).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<({String platform, String? deviceModel, String? osVersion, String? deviceId})> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        // Persist a stable random UUID as deviceId for Android
        final prefs = await SharedPreferences.getInstance();
        String? deviceId = prefs.getString(_kDeviceIdKey);
        if (deviceId == null || deviceId.isEmpty) {
          deviceId = const Uuid().v4();
          await prefs.setString(_kDeviceIdKey, deviceId);
        }
        return (
          platform: 'android',
          deviceModel: '${info.brand} ${info.model}',
          osVersion: info.version.release,
          deviceId: deviceId,
        );
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return (
          platform: 'ios',
          deviceModel: info.utsname.machine,
          osVersion: info.systemVersion,
          deviceId: info.identifierForVendor,
        );
      }
    } catch (_) {}
    return (platform: 'unknown', deviceModel: null, osVersion: null, deviceId: null);
  }

  static Future<String?> _getFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request notification permission
      if (Platform.isIOS) {
        await messaging.requestPermission();
      } else if (Platform.isAndroid) {
        // Android 13+ requires runtime notification permission
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<LoginAuditModel> buildAudit(String userId) async {
    final ip = await _getPublicIp();
    final device = await _getDeviceInfo();
    final pkg = await PackageInfo.fromPlatform();
    final fcm = await _getFcmToken();
    final loc = await _getLocation();

    return LoginAuditModel(
      userId: userId,
      createdAt: DateTime.now().toUtc(),
      platform: device.platform,
      ip: ip,
      deviceId: device.deviceId,
      deviceModel: device.deviceModel,
      appVersion: pkg.version,
      osVersion: device.osVersion,
      pushToken: fcm,
      location: loc,
      extra: null,
    );
  }
}
