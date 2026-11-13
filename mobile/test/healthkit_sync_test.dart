import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/settings_storage.dart';

import 'helpers/fake_backend.dart';

void main() {
  const channel = MethodChannel('healthtrack/health');

  void mockHealthKit() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'isAvailable':
            case 'requestAuthorization':
              return true;
            case 'fetch':
              return (call.arguments as Map)['type'] == 'steps'
                  ? [
                      {'day': '2026-11-10', 'steps': 8200},
                    ]
                  : <Object>[];
          }
          return null;
        });
  }

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'bật Đồng bộ Apple Health ở Hồ sơ: xin quyền rồi gửi dữ liệu lên máy chủ',
    (tester) async {
      mockHealthKit();
      final app = await pumpApp(
        tester,
        providerOverrides: [
          settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
        ],
        overrides: {
          'POST /sync/healthkit': (_) => const FakeResponse(200, {
            'steps': {'created': 1, 'updated': 0},
            'sleep': {'created': 0, 'updated': 0},
            'weights': {'created': 0, 'updated': 0},
          }),
        },
      );
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(routerProvider)
          .go('/profile');
      await tester.pumpAndSettle();

      expect(find.text('Đồng bộ Apple Health'), findsOneWidget);
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(app.backend.count('POST /sync/healthkit'), 1);
      final body =
          app.backend.requests
                  .firstWhere((r) => r.path == '/sync/healthkit')
                  .data
              as Map;
      expect((body['steps'] as List).single['steps'], 8200);
      expect(find.textContaining('Đã đồng bộ lúc'), findsOneWidget);
    },
  );

  testWidgets('máy không có HealthKit thì ẩn công tắc', (tester) async {
    await pumpApp(
      tester,
      providerOverrides: [
        settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
      ],
    );
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Đồng bộ Apple Health'), findsNothing);
  });
}
