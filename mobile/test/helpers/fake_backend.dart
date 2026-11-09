import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/api_client.dart';
import 'package:healthtrack/core/token_storage.dart';
import 'package:healthtrack/features/auth/auth_controller.dart';
import 'package:healthtrack/main.dart';

/// Phản hồi giả: mã HTTP và nội dung JSON.
class FakeResponse {
  const FakeResponse(this.status, [this.body]);

  final int status;
  final Object? body;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(RequestOptions options);

/// Backend giả ở tầng HTTP: test chạy qua Dio, repository và interceptor thật.
/// Khóa là "METHOD /đường-dẫn" (không gồm query), ví dụ "GET /users/me".
class FakeBackend implements HttpClientAdapter {
  FakeBackend(Map<String, FakeHandler> routes) : routes = {...routes};

  final Map<String, FakeHandler> routes;
  final List<RequestOptions> requests = [];

  int count(String key) =>
      requests.where((r) => '${r.method} ${r.path}' == key).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final res = handler == null
        ? const FakeResponse(404, {'detail': 'Không có route giả'})
        : await handler(options);
    final data = res.body == null ? '' : jsonEncode(res.body);
    return ResponseBody.fromString(
      data,
      res.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const demoUser = {
  'id': 1,
  'email': 'demo@healthtrack.example',
  'full_name': 'Người dùng Demo',
  'birth_date': null,
  'gender': null,
  'height_cm': 170.0,
  'created_at': '2026-11-01T00:00:00Z',
};

Map<String, Object?> tokenPair([String suffix = '1']) => {
  'access_token': 'access-$suffix',
  'refresh_token': 'refresh-$suffix',
  'token_type': 'bearer',
};

/// Các route mặc định: người dùng demo đã có ít dữ liệu.
Map<String, FakeHandler> defaultRoutes() {
  final now = DateTime.now().toUtc();
  String ago(Duration d) => now.subtract(d).toIso8601String();
  return {
    'POST /auth/login': (o) {
      final body = o.data as Map;
      return body['password'] == 'matkhau123'
          ? FakeResponse(200, tokenPair())
          : const FakeResponse(401, {
              'detail': 'Email hoặc mật khẩu không đúng',
            });
    },
    'POST /auth/register': (o) => const FakeResponse(201, demoUser),
    'GET /users/me': (_) => const FakeResponse(200, demoUser),
    'PATCH /users/me': (o) => FakeResponse(200, {
      ...demoUser,
      ...(o.data as Map).cast<String, Object?>(),
    }),
    'GET /weights': (_) => FakeResponse(200, [
      {
        'id': 2,
        'weight_kg': 66.6,
        'bmi': 23.0,
        'logged_at': ago(Duration.zero),
      },
      {
        'id': 1,
        'weight_kg': 67.2,
        'bmi': 23.3,
        'logged_at': ago(const Duration(days: 3)),
      },
    ]),
    'GET /water': (_) => FakeResponse(200, [
      {'id': 1, 'amount_ml': 500, 'logged_at': ago(const Duration(minutes: 1))},
      {'id': 2, 'amount_ml': 300, 'logged_at': ago(const Duration(minutes: 2))},
    ]),
    'GET /sleep': (_) => FakeResponse(200, [
      {
        'id': 1,
        'start_at': ago(const Duration(hours: 17)),
        'end_at': ago(const Duration(hours: 9)),
        'quality': 4,
        'duration_minutes': 480,
      },
    ]),
    'GET /stats/summary': (_) => const FakeResponse(200, {
      'date': '2026-11-09',
      'weight': null,
      'water_ml': 800,
      'sleep_minutes': 480,
      'medications': {'taken': 0, 'missed': 0},
      'goals': <Object>[],
    }),
    'GET /stats/trend': (_) => FakeResponse(200, {
      'metric': 'water',
      'unit': 'ml',
      'range': '7d',
      'from_date': '2026-11-03',
      'to_date': '2026-11-09',
      'points': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-11-0${3 + i}',
            'value': i == 6 ? 800 : (i == 0 ? null : 500),
          },
      ],
    }),
    'GET /goals': (_) => const FakeResponse(200, <Object>[]),
    'GET /medications': (_) => const FakeResponse(200, [
      {
        'id': 7,
        'name': 'Vitamin C',
        'dosage': '500mg',
        'schedule': null,
        'is_active': true,
      },
    ]),
    'GET /medications/7/logs': (_) => const FakeResponse(200, <Object>[]),
    'POST /water': (_) => const FakeResponse(201, {
      'id': 9,
      'amount_ml': 250,
      'logged_at': '2026-11-09T00:00:00Z',
    }),
    'POST /weights': (_) => const FakeResponse(201, {
      'id': 9,
      'weight_kg': 70,
      'bmi': 24.2,
      'logged_at': '2026-11-09T00:00:00Z',
    }),
  };
}

/// Dựng app với backend giả. [loggedIn] = true thì đã có token trong bộ nhớ.
Future<
  ({
    FakeBackend backend,
    MemoryTokenStorage storage,
    ProviderContainer container,
  })
>
pumpApp(
  WidgetTester tester, {
  bool loggedIn = true,
  Map<String, FakeHandler> overrides = const {},
}) async {
  final backend = FakeBackend({...defaultRoutes(), ...overrides});
  final storage = MemoryTokenStorage(
    loggedIn ? const Tokens(access: 'access-1', refresh: 'refresh-1') : null,
  );
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://fake.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = backend;
  final retryDio = Dio(
    BaseOptions(
      baseUrl: 'http://fake.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = backend;
  late final ProviderContainer container;
  final scope = ProviderScope(
    retry: noRetry,
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) {
        dio.interceptors.add(
          AuthInterceptor(
            storage: storage,
            retryDio: retryDio,
            onSessionExpired: () =>
                ref.read(authProvider.notifier).onSessionExpired(),
          ),
        );
        return dio;
      }),
    ],
    child: const HealthTrackApp(),
  );
  await tester.pumpWidget(scope);
  container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  await tester.pumpAndSettle();
  return (backend: backend, storage: storage, container: container);
}
