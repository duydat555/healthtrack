import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_tracker/route_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('flattenPoints: ba số mỗi điểm, tốc độ không rõ là -1', () {
    final flat = flattenPoints(const [
      MapPoint(16.06, 108.22, 3.1),
      MapPoint(16.07, 108.23),
    ]);
    expect(flat, Float64List.fromList([16.06, 108.22, 3.1, 16.07, 108.23, -1]));
  });

  group('RoutePainter', () {
    test(
      'chuẩn hóa tốc độ theo phân vị 10–90%: chậm 0, nhanh 1, đều thì 0,5',
      () {
        final pts = [
          for (var i = 0; i < 11; i++)
            MapPoint(16, 108 + i * 1e-4, 2.0 + i * 0.2),
        ];
        final t = RoutePainter.normalizedSpeeds(pts);
        expect(t.first, 0);
        expect(t.last, 1);
        expect(t[5], closeTo(0.5, 0.15));
        final flat = [
          for (var i = 0; i < 5; i++) MapPoint(16, 108 + i * 1e-4, 3),
        ];
        expect(RoutePainter.normalizedSpeeds(flat), everyElement(0.5));
        expect(
          RoutePainter.normalizedSpeeds(const [
            MapPoint(16, 108),
            MapPoint(16, 108.1),
          ]),
          everyElement(0.5),
        );
      },
    );

    test(
      'làm mượt tốc độ: nhiễu từng điểm bị triệt, xu hướng chậm dần vẫn còn',
      () {
        // Nhiễu ±0,3 m/s quanh tốc độ giảm dần từ 4 xuống 2 m/s
        final pts = [
          for (var i = 0; i < 60; i++)
            MapPoint(
              16,
              108 + i * 1e-4,
              4 - i * 2 / 59 + (i.isEven ? 0.3 : -0.3),
            ),
        ];
        final smooth = RoutePainter.smoothSpeeds(pts);
        var rawJitter = 0.0, smoothJitter = 0.0;
        for (var i = 1; i < pts.length; i++) {
          rawJitter += (pts[i].speed! - pts[i - 1].speed!).abs();
          smoothJitter += (smooth[i] - smooth[i - 1]).abs();
        }
        expect(smoothJitter, lessThan(rawJitter * 0.2));
        expect(smooth[10], greaterThan(smooth[50] + 1));
        // Tốc độ không rõ lấy theo điểm trước, không gây lỗi
        expect(
          RoutePainter.smoothSpeeds(const [
            MapPoint(0, 0),
            MapPoint(0, 0, 3),
            MapPoint(0, 0),
          ]),
          everyElement(3),
        );
      },
    );

    test('nội suy màu giữa các mốc', () {
      const stops = [Color(0xFF000000), Color(0xFFFFFFFF)];
      expect(RoutePainter.colorAt(stops, 0), const Color(0xFF000000));
      expect(RoutePainter.colorAt(stops, 1), const Color(0xFFFFFFFF));
      expect(
        RoutePainter.colorAt(defaultRouteGradient, 0),
        defaultRouteGradient.first,
      );
      expect(
        RoutePainter.colorAt(defaultRouteGradient, 1),
        defaultRouteGradient.last,
      );
    });

    testWidgets(
      'vẽ được đường đi trong khung và không ném lỗi khi quá ít điểm',
      (tester) async {
        for (final pts in [
          const <MapPoint>[],
          const [MapPoint(16, 108)],
          [
            for (var i = 0; i < 50; i++)
              MapPoint(16 + i * 1e-4, 108 + i * 1e-4, 3),
          ],
        ]) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 300,
                height: 300,
                child: CustomPaint(
                  painter: RoutePainter(points: pts, background: Colors.black),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('RouteMapController và RouteMapView', () {
    testWidgets(
      'bản dự phòng (không phải iOS) vẽ lộ trình đã đặt, đổi lộ trình thì vẽ lại',
      (tester) async {
        final c = RouteMapController();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RouteMapView(controller: c),
          ),
        );
        expect(find.byType(CustomPaint), findsWidgets);
        await c.setRoute([
          for (var i = 0; i < 20; i++) MapPoint(16 + i * 1e-4, 108, 3),
        ]);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'gửi đúng lệnh sang native, gửi lại lộ trình khi gắn kênh, nhận onFollow',
      () async {
        final calls = <MethodCall>[];
        const channel = MethodChannel('healthtrack/route_map/7');
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final c = RouteMapController();
        addTearDown(c.dispose);

        // Đặt lộ trình trước khi bản đồ dựng xong: chưa gửi gì, nhưng được gửi lại khi kênh gắn
        const pts = [MapPoint(16, 108, 3), MapPoint(16.001, 108, 3)];
        await c.setRoute(pts);
        expect(calls, isEmpty);
        c.attach(channel);
        await Future<void>.delayed(Duration.zero);
        expect(calls.single.method, 'setRoute');
        expect((calls.single.arguments as Map)['points'], flattenPoints(pts));

        calls.clear();
        await c.appendPoints(const [MapPoint(16.002, 108, 3)]);
        await c.recenter();
        await c.fitRoute(padding: 30);
        await c.setFollow(false);
        await c.setMapType(RouteMapType.hybrid);
        expect(calls.map((m) => m.method), [
          'appendPoints',
          'recenter',
          'fitRoute',
          'setFollow',
          'setMapType',
        ]);
        expect((calls[2].arguments as Map)['padding'], 30.0);
        expect((calls[4].arguments as Map)['mapType'], 'hybrid');

        // Native báo người dùng đã kéo bản đồ: nút định vị lại cần hiện
        expect(c.following.value, isTrue);
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onFollow', false),
          ),
          (_) {},
        );
        expect(c.following.value, isFalse);
      },
    );
  });

  test('snapshotRoute gửi điểm, kích thước và bảng màu, trả ảnh PNG', () async {
    const channel = MethodChannel('healthtrack/route');
    Map<Object?, Object?>? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call.arguments as Map<Object?, Object?>;
      return Uint8List.fromList([137, 80, 78, 71]);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final png = await const RouteTracker().snapshotRoute(
      const [MapPoint(16, 108, 3), MapPoint(16.001, 108, 3.5)],
      width: 800,
      height: 600,
      dark: true,
      mapType: RouteMapType.satellite,
    );
    expect(png.take(4), [137, 80, 78, 71]);
    expect(sent!['width'], 800.0);
    expect(sent!['height'], 600.0);
    expect(sent!['mapType'], 'satellite');
    expect(sent!['dark'], isTrue);
    expect((sent!['gradient'] as List).length, 3);
    expect(sent!.containsKey('lineWidth'), isFalse);
  });
}
