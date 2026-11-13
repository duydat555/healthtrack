import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

void main() {
  const channel = MethodChannel('healthtrack/widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets('Tổng quan đẩy số liệu hôm nay sang widget qua App Group', (
    tester,
  ) async {
    await pumpApp(tester);
    final save = calls.where((c) => c.method == 'saveSnapshot');
    expect(save, isNotEmpty);
    final json =
        jsonDecode(save.last.arguments as String) as Map<String, dynamic>;
    expect(json['score'], 62);
    expect(json['streak'], 3);
    expect(json['waterMl'], 800);
    expect(json['waterGoalMl'], 2000);
    expect(json['sleepMinutes'], 480);
    // Mới mở app, nước chưa tăng nên chưa bật Live Activity
    expect(calls.where((c) => c.method == 'waterActivity'), isEmpty);
  });
}
