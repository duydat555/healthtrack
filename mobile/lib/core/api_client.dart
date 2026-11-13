import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'token_storage.dart';

/// Địa chỉ API, đổi khi chạy: flutter run --dart-define=API_URL=https://...
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

const _authPaths = ['/auth/login', '/auth/register', '/auth/refresh'];

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: apiBaseUrl,
  // Render gói free ngủ khi lâu không có người dùng, lần gọi đầu có thể mất 30-60 giây
  connectTimeout: const Duration(seconds: 60),
  receiveTimeout: const Duration(seconds: 60),
  contentType: Headers.jsonContentType,
);

/// Gắn access token vào mọi request; gặp 401 thì dùng refresh token lấy cặp mới rồi thử lại
/// đúng một lần. Nhiều request cùng 401 sẽ chỉ làm mới một lần. Làm mới thất bại thì xóa
/// phiên và báo [onSessionExpired] để đưa người dùng về màn đăng nhập.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.retryDio,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// Dio dùng để làm mới token và gửi lại request, không có interceptor để tránh vòng lặp.
  final Dio retryDio;
  final void Function() onSessionExpired;

  Future<Tokens?>? _refreshing;

  bool _isAuthPath(RequestOptions o) => _authPaths.any(o.path.endsWith);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options)) {
      final tokens = await storage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.access}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isAuthPath(req) ||
        req.extra['retried'] == true) {
      return handler.next(err);
    }

    final fresh = await (_refreshing ??= _refresh().whenComplete(
      () => _refreshing = null,
    ));
    if (fresh == null) {
      onSessionExpired();
      return handler.next(err);
    }

    try {
      req.extra['retried'] = true;
      req.headers['Authorization'] = 'Bearer ${fresh.access}';
      handler.resolve(await retryDio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<Tokens?> _refresh() async {
    final current = await storage.read();
    if (current == null) return null;
    try {
      final res = await retryDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': current.refresh},
      );
      final data = res.data!;
      final tokens = Tokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      await storage.save(tokens);
      return tokens;
    } on DioException {
      await storage.clear();
      return null;
    }
  }
}

/// Gọi nhẹ tới máy chủ ngay khi mở app để đánh thức Render trước khi người dùng đăng nhập.
/// Mọi lỗi đều bỏ qua.
Future<void> warmUpServer() async {
  try {
    final root = Uri.parse(apiBaseUrl).replace(path: '/health');
    await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
        validateStatus: (_) => true,
      ),
    ).getUri<void>(root);
  } catch (_) {}
}

/// Dio dùng chung cho toàn app.
final dioProvider = Provider<Dio>((ref) {
  final retryDio = Dio(_baseOptions());
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      retryDio: retryDio,
      onSessionExpired: () =>
          ref.read(authProvider.notifier).onSessionExpired(),
    ),
  );
  return dio;
});

/// Chuyển lỗi mạng thành câu tiếng Việt để hiện cho người dùng.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
      default:
        break;
    }
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (error.response?.statusCode == 422) return 'Dữ liệu chưa hợp lệ.';
    if (error.response?.statusCode == 429) {
      return 'Thử quá nhiều lần, vui lòng đợi một lát.';
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      return 'Máy chủ gặp sự cố, thử lại sau.';
    }
  }
  return 'Có lỗi xảy ra, vui lòng thử lại.';
}
