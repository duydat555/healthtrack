import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/health_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('healthtrack/health');

  void mock(Future<Object?>? Function(MethodCall) handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);

  tearDown(() => mock((_) async => null));

  test('isAvailable trả về false khi không có plugin', () async {
    expect(await const HealthBridge().isAvailable(), isFalse);
  });

  test('read gom bước chân, giấc ngủ và cân nặng thành một lô', () async {
    final calls = <MethodCall>[];
    mock((call) async {
      calls.add(call);
      switch ((call.arguments as Map)['type']) {
        case 'steps':
          return [
            {'day': '2026-11-10', 'steps': 8200},
          ];
        case 'sleep':
          return [
            {
              'external_id': 's1',
              'start_at': '2026-11-10T16:00:00Z',
              'end_at': '2026-11-10T23:30:00Z',
            },
          ];
        default:
          return <Object>[];
      }
    });
    final from = DateTime.utc(2026, 11, 3);
    final to = DateTime.utc(2026, 11, 10);
    final batch = await const HealthBridge().read(from, to);
    expect(batch.steps.single['steps'], 8200);
    expect(batch.sleep.single['external_id'], 's1');
    expect(batch.weights, isEmpty);
    expect(batch.isEmpty, isFalse);
    expect(batch.toJson().keys, ['steps', 'sleep', 'weights']);
    expect(calls.map((c) => (c.arguments as Map)['type']), [
      'steps',
      'sleep',
      'weight',
    ]);
    expect((calls.first.arguments as Map)['from'], from.millisecondsSinceEpoch);
  });
}
