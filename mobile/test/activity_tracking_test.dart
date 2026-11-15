import 'dart:async';

import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/settings_storage.dart';
import 'package:healthtrack/features/activity/activity_tracking.dart';

import 'helpers/fake_backend.dart';

/// Cảm biến giả: có máy đếm bước, đêm qua nằm yên 23:00 → 6:30, hôm nay đi 5.000 bước.
class FakeSensors implements ActivitySensors {
  FakeSensors({this.restAccessGranted = true});

  final bool restAccessGranted;
  final live = StreamController<int>.broadcast();
  int permissionRequests = 0;

  /// Giờ cố định của test: 10:00 ngày 15/11/2026, sau giờ dậy 06:30 và không phụ thuộc lúc chạy.
  static DateTime get fixedNow => DateTime(2026, 11, 15, 10);

  DateTime get _today => DateTime(2026, 11, 15);

  String get _todayKey =>
      '${_today.year}-${_today.month.toString().padLeft(2, '0')}-${_today.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ActivityPermission> permission() async =>
      ActivityPermission.notDetermined;

  @override
  Future<ActivityPermission> requestPermission() async {
    permissionRequests++;
    return ActivityPermission.granted;
  }

  @override
  Future<List<DailySteps>> dailySteps(DateTime from, DateTime to) async => [
    DailySteps(day: _todayKey, steps: 5000, distanceM: 3600),
  ];

  /// Dùng máy liên tục tới 23:00 hôm qua và từ 06:30 sáng nay tới giờ.
  @override
  Future<List<DateTime>> wakeEvents(DateTime from, DateTime to) async {
    if (!restAccessGranted) return const [];
    final out = <DateTime>[];
    void fill(DateTime a, DateTime b) {
      for (var x = a; x.isBefore(b); x = x.add(const Duration(minutes: 15))) {
        out
          ..add(x.add(const Duration(minutes: 2)))
          ..add(x.add(const Duration(minutes: 9)));
      }
    }

    fill(
      _today.subtract(const Duration(hours: 8)),
      _today.subtract(const Duration(hours: 1)),
    );
    fill(_today.add(const Duration(hours: 6, minutes: 30)), to);
    return out;
  }

  @override
  Future<List<StepWindow>> stepBuckets(
    DateTime from,
    DateTime to, {
    int minutes = 15,
  }) async => const [];

  @override
  Future<List<RestInterval>> sleepSegments(DateTime from, DateTime to) async =>
      const [];

  @override
  Future<void> startBackground() async {}

  @override
  Future<bool> restAccess() async => restAccessGranted;

  @override
  Future<void> openRestAccessSettings() async {}

  @override
  Stream<int> todaySteps() => live.stream;
}

void main() {
  // Máy trong test không có Apple Health (giống bản cài lại không có quyền HealthKit)
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('healthtrack/health'),
          (call) async => call.method == 'isAvailable' ? false : null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('healthtrack/health'),
          null,
        ),
  );

  Future<({FakeBackend backend, FakeSensors sensors})> open(
    WidgetTester tester, {
    bool restAccess = true,
  }) async {
    final sensors = FakeSensors(restAccessGranted: restAccess);
    final app = await pumpApp(
      tester,
      providerOverrides: [
        settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
        activitySensorsProvider.overrideWithValue(sensors),
        clockProvider.overrideWithValue(() => FakeSensors.fixedNow),
      ],
      overrides: {
        'POST /sync/healthkit': (_) => const FakeResponse(200, {
          'steps': {'created': 1, 'updated': 0},
          'sleep': {'created': 1, 'updated': 0},
          'weights': {'created': 0, 'updated': 0},
        }),
      },
    );
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go('/profile');
    await tester.pumpAndSettle();
    return (backend: app.backend, sensors: sensors);
  }

  testWidgets(
    'bật Theo dõi vận động: xin quyền, gửi bước chân và giấc ngủ ước lượng với nguồn device',
    (tester) async {
      final app = await open(tester);
      final row = find.text('Theo dõi vận động');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      final toggle = find.descendant(
        of: find.ancestor(of: row, matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      // ignore: avoid_print
      expect(app.sensors.permissionRequests, 1);
      final body =
          app.backend.requests
                  .lastWhere((r) => r.path == '/sync/healthkit')
                  .data
              as Map;
      expect(body['source'], 'device');
      expect((body['steps'] as List).single['steps'], 5000);
      final sleep = (body['sleep'] as List).single as Map;
      expect(sleep['external_id'], startsWith('device-sleep-'));
      // Mô hình thấy hết dùng máy lúc 23:00 và dùng lại lúc 06:30
      final start = DateTime.parse(sleep['start_at'] as String).toLocal();
      final end = DateTime.parse(sleep['end_at'] as String).toLocal();
      expect((start.hour, start.minute), (23, 0));
      expect((end.hour, end.minute), (6, 30));
      expect(find.textContaining('Hôm nay 5.000 bước'), findsOneWidget);

      // Bước chân trực tiếp cập nhật khi đang đi
      app.sensors.live.add(5200);
      await tester.pumpAndSettle();
      expect(find.textContaining('Hôm nay 5.200 bước'), findsOneWidget);
    },
  );

  testWidgets(
    'Android chưa cấp quyền đọc giờ tắt màn hình: hiện hàng nhắc cấp quyền',
    (tester) async {
      await open(tester, restAccess: false);
      final row = find.text('Theo dõi vận động');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: row, matching: find.byType(Row)).first,
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cho phép ước lượng giấc ngủ'), findsOneWidget);
    },
  );

  testWidgets(
    'iPhone có Apple Health: dùng giấc ngủ và năng lượng của Apple thay cho mô hình',
    (tester) async {
      final today = DateTime(2026, 11, 15);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('healthtrack/health'), (
            call,
          ) async {
            switch (call.method) {
              case 'isAvailable':
              case 'requestAuthorization':
                return true;
              case 'fetch':
                return switch ((call.arguments as Map)['type']) {
                  'sleep' => [
                    {
                      'external_id': 'HK-UUID-1',
                      'start_at': today
                          .subtract(const Duration(minutes: 30))
                          .toUtc()
                          .toIso8601String(),
                      'end_at': today
                          .add(const Duration(hours: 7))
                          .toUtc()
                          .toIso8601String(),
                    },
                  ],
                  'energy' => [
                    {'kcal': 321.0},
                  ],
                  _ => <Object>[],
                };
            }
            return null;
          });
      final app = await open(tester);
      final row = find.text('Theo dõi vận động');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: row, matching: find.byType(Row)).first,
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      final body =
          app.backend.requests
                  .lastWhere((r) => r.path == '/sync/healthkit')
                  .data
              as Map;
      final sleep = (body['sleep'] as List).single as Map;
      expect(sleep['external_id'], 'HK-UUID-1');
      final state = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(activityTrackingProvider);
      expect(state.sleepSource, 'apple');
      expect(state.appleActiveKcal, 321);
    },
  );
}
