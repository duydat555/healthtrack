import 'package:dio/dio.dart';

/// Địa chỉ API, đổi khi chạy: flutter run --dart-define=API_URL=https://...
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

/// Dio dùng chung. Interceptor gắn token và tự làm mới phiên: issue Phase 1 (Mobile).
final dio = Dio(
  BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);
