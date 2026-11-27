import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_tracker/route_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('healthtrack/route');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('đọc quyền, xin quyền và vị trí gần nhất', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'permission':
          return 'whenInUse';
        case 'requestPermission':
          return 'always';
        case 'lastKnown':
          return {
            'lat': 16.06,
            'lon': 108.22,
            'acc': 8.0,
            't': 1000,
            'speed': 2.5,
          };
      }
      return null;
    });
    const rt = RouteTracker();
    expect(await rt.permission(), LocationPermission.whenInUse);
    expect((await rt.permission()).granted, isTrue);
    expect(await rt.requestPermission(), LocationPermission.always);
    final fix = await rt.lastKnown();
    expect(fix!.lat, 16.06);
    expect(fix.speed, 2.5);
    expect(fix.alt, isNull);
    expect(fix.t.millisecondsSinceEpoch, 1000);
    await rt.start(distanceFilterM: 5);
    await rt.stop();
    expect(calls, containsAll(['start', 'stop']));
  });

  test('không có plugin thì báo không hỗ trợ thay vì lỗi', () async {
    const rt = RouteTracker(channel: MethodChannel('khong_ton_tai'));
    expect(await rt.isAvailable(), isFalse);
    expect(await rt.permission(), LocationPermission.unavailable);
    expect(await rt.lastKnown(), isNull);
    await rt.stop();
  });
}
