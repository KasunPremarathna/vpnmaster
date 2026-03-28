import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'device_id_persistent';
  
  static String? _cachedId;

  /// Gets a persistent, unique Device ID.
  /// It tries to use hardware IDs first, then falls back to a generated UUID
  /// stored in secure storage.
  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;

    final deviceInfo = DeviceInfoPlugin();
    String? id;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id; // androidId
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor;
      }
    } catch (e) {
      // Fallback to secure storage if hardware info fails
    }

    // If still null or default, use/generate a UUID
    if (id == null || id.isEmpty || id == 'unknown') {
      id = await _storage.read(key: _deviceIdKey);
      if (id == null) {
        id = const Uuid().v4();
        await _storage.write(key: _deviceIdKey, value: id);
      }
    }

    _cachedId = id;
    return id;
  }
}
