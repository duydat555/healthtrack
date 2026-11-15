import 'dart:async';

import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/material.dart';
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

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

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

  @override
  Future<List<RestInterval>> restIntervals(DateTime from, DateTime to) async =>
      restAccessGranted
      ? [
          RestInterval(
            _today.subtract(const Duration(hours: 1)),
            _today.add(const Duration(hours: 6, minutes: 30)),
          ),
        ]
      : const [];

  @override
  Future<bool> restAccess() async => restAccessGranted;

  @override
  Future<void> openRestAccessSettings() async {}

  @override
  Stream<int> todaySteps() => live.stream;
}

void main() {
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
      // Nằm yên từ 23:00, trừ 10 phút chưa ngủ
      final start = DateTime.parse(sleep['start_at'] as String).toLocal();
      expect(start.hour, 23);
      expect(start.minute, 10);
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
}
