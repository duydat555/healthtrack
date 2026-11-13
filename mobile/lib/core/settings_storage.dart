import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu cài đặt nhỏ của người dùng (cờ bật/tắt). Test dùng bản trong bộ nhớ.
abstract class SettingsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureSettingsStorage implements SettingsStorage {
  const SecureSettingsStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: 'setting_$key');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: 'setting_$key', value: value);
    } catch (_) {}
  }
}

class MemorySettingsStorage implements SettingsStorage {
  MemorySettingsStorage([Map<String, String>? initial]) : _data = {...?initial};

  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => const SecureSettingsStorage(),
);
