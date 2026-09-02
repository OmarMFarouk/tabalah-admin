import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSecured {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> saveString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readString(String key) async {
    return await _secureStorage.read(key: key);
  }

  static Future<void> saveBool(String key, bool value) async {
    await _secureStorage.write(key: key, value: value.toString());
  }

  static Future<bool?> readBool(String key) async {
    String? value = await _secureStorage.read(key: key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  static Future<void> saveMap(String key, Map<String, dynamic> value) async {
    await _secureStorage.write(key: key, value: jsonEncode(value));
  }

  static Future<Map<String, dynamic>?> readMap(String key) async {
    final raw = await _secureStorage.read(key: key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String key) async {
    await _secureStorage.delete(key: key);
  }

  static Future<void> clear() async {
    await _secureStorage.deleteAll();
  }
}
