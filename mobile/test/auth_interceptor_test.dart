import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/api_client.dart';
import 'package:healthtrack/core/token_storage.dart';

import 'helpers/fake_backend.dart';

({Dio dio, FakeBackend backend, MemoryTokenStorage storage, List<int> expired})
_setup(
  Map<String, FakeHandler> routes, {
  Tokens? tokens = const Tokens(access: 'old', refresh: 'refresh-old'),
}) {
  final backend = FakeBackend(routes);
  final storage = MemoryTokenStorage(tokens);
  final expired = <int>[];
  Dio make() =>
      Dio(BaseOptions(baseUrl: 'http://fake.test'))
        ..httpClientAdapter = backend;
  final dio = make()
    ..interceptors.add(
      AuthInterceptor(
        storage: storage,
        retryDio: make(),
        onSessionExpired: () => expired.add(1),
      ),
    );
  return (dio: dio, backend: backend, storage: storage, expired: expired);
}

String? _bearer(RequestOptions o) => o.headers['Authorization'] as String?;

void main() {
  test(
    'gắn Bearer access token vào request thường, không gắn vào /auth/login',
    () async {
      final s = _setup({
        'GET /weights': (_) => const FakeResponse(200, <Object>[]),
        'POST /auth/login': (_) => FakeResponse(200, tokenPair()),
      });
      await s.dio.get<void>('/weights');
      await s.dio.post<void>(
        '/auth/login',
        data: {'email': 'a', 'password': 'b'},
      );
      expect(_bearer(s.backend.requests[0]), 'Bearer old');
      expect(_bearer(s.backend.requests[1]), isNull);
    },
  );

  test('401 thì làm mới token rồi thử lại, lưu cặp token mới', () async {
    var first = true;
    final s = _setup({
      'GET /weights': (o) {
        if (first) {
          first = false;
          return const FakeResponse(401, {'detail': 'hết hạn'});
        }
        return FakeResponse(200, [
          {'ok': _bearer(o)},
        ]);
      },
      'POST /auth/refresh': (o) {
        expect((o.data as Map)['refresh_token'], 'refresh-old');
        return FakeResponse(200, tokenPair('new'));
      },
    });
    final res = await s.dio.get<List<dynamic>>('/weights');
    expect(res.data!.first['ok'], 'Bearer access-new');
    expect((await s.storage.read())!.refresh, 'refresh-new');
    expect(s.backend.count('POST /auth/refresh'), 1);
    expect(s.expired, isEmpty);
  });

  test('nhiều request cùng 401 chỉ làm mới token một lần', () async {
    final seen = <String>{};
    final s = _setup({
      'GET /weights': (o) {
        final auth = _bearer(o)!;
        if (auth == 'Bearer old') {
          return const FakeResponse(401, {'detail': 'hết hạn'});
        }
        seen.add(auth);
        return const FakeResponse(200, <Object>[]);
      },
      'GET /water': (o) => _bearer(o) == 'Bearer old'
          ? const FakeResponse(401, {'detail': 'hết hạn'})
          : const FakeResponse(200, <Object>[]),
      'POST /auth/refresh': (_) => FakeResponse(200, tokenPair('new')),
    });
    await Future.wait([
      s.dio.get<void>('/weights'),
      s.dio.get<void>('/water'),
      s.dio.get<void>('/weights'),
    ]);
    expect(s.backend.count('POST /auth/refresh'), 1);
    expect(seen, {'Bearer access-new'});
  });

  test('làm mới thất bại: xóa token, báo hết phiên, trả lỗi 401 gốc', () async {
    final s = _setup({
      'GET /weights': (_) => const FakeResponse(401, {'detail': 'hết hạn'}),
      'POST /auth/refresh': (_) =>
          const FakeResponse(401, {'detail': 'hết hạn'}),
    });
    await expectLater(
      s.dio.get<void>('/weights'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(await s.storage.read(), isNull);
    expect(s.expired, [1]);
  });

  test('chỉ thử lại một lần: sau khi làm mới mà vẫn 401 thì dừng, không lặp vô hạn', () async {
    final s = _setup({
      'GET /weights': (_) => const FakeResponse(401, {'detail': 'vẫn từ chối'}),
      'POST /auth/refresh': (_) => FakeResponse(200, tokenPair('new')),
    });
    await expectLater(
      s.dio.get<void>('/weights'),
      throwsA(isA<DioException>()),
    );
    expect(s.backend.count('GET /weights'), 2);
    expect(s.backend.count('POST /auth/refresh'), 1);
  });

  test('401 ở /auth/login không kích hoạt làm mới token', () async {
    final s = _setup({
      'POST /auth/login': (_) =>
          const FakeResponse(401, {'detail': 'sai mật khẩu'}),
    });
    await expectLater(
      s.dio.post<void>('/auth/login', data: {'email': 'a', 'password': 'b'}),
      throwsA(isA<DioException>()),
    );
    expect(s.backend.count('POST /auth/refresh'), 0);
    expect(s.expired, isEmpty);
  });

  test('lỗi không phải 401 được giữ nguyên', () async {
    final s = _setup({
      'GET /weights': (_) => const FakeResponse(500, {'detail': 'lỗi'}),
    });
    await expectLater(
      s.dio.get<void>('/weights'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          500,
        ),
      ),
    );
    expect(s.backend.count('POST /auth/refresh'), 0);
  });

  test('apiErrorMessage đọc detail của máy chủ và xử lý lỗi mạng', () {
    DioException err(int status, Object? data) => DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: status,
        data: data,
      ),
    );
    expect(
      apiErrorMessage(err(409, {'detail': 'Email đã được đăng ký'})),
      'Email đã được đăng ký',
    );
    expect(
      apiErrorMessage(err(422, {'detail': <Object>[]})),
      'Dữ liệu chưa hợp lệ.',
    );
    expect(apiErrorMessage(err(429, null)), contains('quá nhiều'));
    expect(apiErrorMessage(err(500, null)), contains('Máy chủ'));
    expect(
      apiErrorMessage(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      ),
      contains('kết nối'),
    );
  });
}
