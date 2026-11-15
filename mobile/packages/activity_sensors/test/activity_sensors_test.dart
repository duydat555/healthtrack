import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('healthtrack/activity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('đọc bước theo ngày và quãng nghỉ, sắp xếp theo thời gian', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'dailySteps':
          return [
            {'day': '2026-11-14', 'steps': 8200, 'distanceM': 6100.5},
            {'day': '2026-11-15', 'steps': 1200},
          ];
        case 'wakeEvents':
          return [3000, 1000];
        case 'sleepSegments':
          return [
            {'start': 2000, 'end': 3000},
            {'start': 0, 'end': 1000},
          ];
        case 'stepBuckets':
          return [
            {'start': 0, 'steps': 900, 'distanceM': 700.0, 'paceSecPerM': 0.4},
          ];
        case 'requestPermission':
          return 'granted';
      }
      return null;
    });
    const sensors = ActivitySensors();
    final days = await sensors.dailySteps(
      DateTime(2026, 11, 14),
      DateTime(2026, 11, 16),
    );
    expect(days.map((d) => d.steps), [8200, 1200]);
    expect(days.first.distanceM, 6100.5);
    expect(days.last.distanceM, isNull);

    final wake = await sensors.wakeEvents(DateTime(2026), DateTime(2027));
    expect(wake.map((e) => e.millisecondsSinceEpoch), [1000, 3000]);
    final sleep = await sensors.sleepSegments(DateTime(2026), DateTime(2027));
    expect(sleep.first.start.millisecondsSinceEpoch, 0);
    final buckets = await sensors.stepBuckets(DateTime(2026), DateTime(2027));
    expect(buckets.single.paceSecPerM, 0.4);
    expect(await sensors.requestPermission(), ActivityPermission.granted);
  });

  test('không có plugin thì báo không hỗ trợ thay vì lỗi', () async {
    const sensors = ActivitySensors(channel: MethodChannel('khong_ton_tai'));
    expect(await sensors.isAvailable(), isFalse);
    expect(await sensors.permission(), ActivityPermission.unavailable);
  });
}
