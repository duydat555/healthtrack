import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import 'user.dart';

/// Gọi các endpoint `/auth/*` và `/users/me`.
class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  Future<bool> hasSession() async => await _storage.read() != null;

  Future<void> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    final data = res.data!;
    await _storage.save(
      Tokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      ),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
      },
    );
    await login(email, password);
  }

  Future<User> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(res.data!);
  }

  Future<User> updateHeight(double heightCm) =>
      updateProfile(heightCm: heightCm);

  Future<User> updateProfile({
    String? fullName,
    DateTime? birthDate,
    String? gender,
    double? heightCm,
  }) async {
    String? formatDate(DateTime? d) => d == null
        ? null
        : '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';

    final res = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {
        if (fullName != null) 'full_name': fullName.trim(),
        if (birthDate != null) 'birth_date': formatDate(birthDate),
        'gender': ?gender,
        'height_cm': ?heightCm,
      },
    );
    return User.fromJson(res.data!);
  }

  Future<void> logout() => _storage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);
