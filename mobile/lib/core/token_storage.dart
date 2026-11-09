import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cặp token của phiên đăng nhập.
@immutable
class Tokens {
  const Tokens({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Nơi lưu token. Bản thật dùng Keychain; test dùng bản trong bộ nhớ.
abstract class TokenStorage {
  Future<Tokens?> read();
  Future<void> save(Tokens tokens);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<Tokens?> read() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access == null || refresh == null) return null;
      return Tokens(access: access, refresh: refresh);
    } catch (_) {
      // Keychain lỗi (ví dụ máy ảo vừa reset): coi như chưa đăng nhập
      return null;
    }
  }

  @override
  Future<void> save(Tokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this._tokens]);

  Tokens? _tokens;

  @override
  Future<Tokens?> read() async => _tokens;

  @override
  Future<void> save(Tokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);
