import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Generates and persists a unique device identifier.
/// The ID is created once and stored in SharedPreferences so it
/// survives app restarts. Each physical device gets its own ID.
class DeviceIdService {
  static DeviceIdService? _instance;
  static DeviceIdService get instance => _instance ??= DeviceIdService._();
  DeviceIdService._();

  static const String _key = 'stocky_device_id';
  String? _cachedId;

  /// Returns the persistent device ID, generating one if it doesn't exist yet.
  Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_key);
    if (stored == null || stored.isEmpty) {
      stored = _generateId();
      await prefs.setString(_key, stored);
      debugPrint('[DeviceIdService] Generated new device_id: $stored');
    } else {
      debugPrint('[DeviceIdService] Loaded existing device_id: $stored');
    }
    _cachedId = stored;
    return _cachedId!;
  }

  /// Generates a random 32-character hex string using dart:math Random.secure().
  /// Uses Random.secure() instead of integer overflow arithmetic so it works
  /// correctly on both Flutter Web (JS/Wasm) and native platforms.
  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
