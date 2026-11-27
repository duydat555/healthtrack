import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_charts.dart';
import 'package:healthtrack/features/workout/workout_summary_screen.dart';

Workout fixture(String id) => Workout.fromJson(
  jsonDecode(File('test/fixtures/workouts/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

void main() {
  group('biểu đồ', () {
    test('nhịp buổi chạy mẫu quanh 5:33/km, nằm trong khoảng hợp lý', () {
      final w = fixture('sample-run-han-river');
      final p = paceProfile(w.points);
      expect(p, isNotEmpty);
      expect(p.last.km, closeTo(w.distanceM / 1000, 0.2));
      for (final x in p) {
        expect(x.value, inInclusiveRange(180, 1200));
      }
      final mean = p.map((x) => x.value).reduce((a, b) => a + b) / p.length;
      expect(mean, closeTo(333, 40));
    });

    test('độ cao theo quãng đường, km tăng dần', () {
      final w = fixture('sample-ride-my-khe');
      final e = elevationProfile(w.points);
      expect(e.length, 81);
      expect(e.first.km, 0);
      for (var i = 1; i < e.length; i++) {
        expect(e[i].km, greaterThanOrEqualTo(e[i - 1].km));
      }
    });

    test('quá ngắn hoặc thiếu độ cao thì không vẽ', () {
      final w = fixture('sample-walk-vku');
      expect(paceProfile(w.points.take(2).toList()), isEmpty);
      final noAlt = [
        for (final p in w.points)
          TrackPoint(lat: p.lat, lon: p.lon, t: p.t, segment: p.segment),
      ];
      expect(elevationProfile(noAlt), isEmpty);
    });
  });

  group('trang tổng kết', () {
    Future<void> pump(WidgetTester tester, Workout w) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SummaryBody(
              workout: w,
              snapshot: (_, _) async =>
                  null, // không có ảnh: dùng bản vẽ dự phòng
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('buổi chạy: số liệu, split, biểu đồ', (tester) async {
      final w = fixture('sample-run-han-river');
      await pump(tester, w);
      expect(find.text(w.title), findsOneWidget);
      expect(find.text('5,19'), findsOneWidget);
      expect(find.text('Nhịp TB (/km)'), findsOneWidget);
      expect(find.text('Từng km'), findsOneWidget);
      expect(find.text('Nhịp'), findsOneWidget);
      expect(find.text('Độ cao'), findsOneWidget);
      expect(find.text('Chia sẻ'), findsOneWidget);
    });

    testWidgets('đạp xe hiện tốc độ km/h thay cho nhịp', (tester) async {
      await pump(tester, fixture('sample-ride-my-khe'));
      expect(find.text('Tốc độ TB (km/h)'), findsOneWidget);
      expect(find.text('Nhịp TB (/km)'), findsNothing);
      expect(find.text('Tốc độ'), findsOneWidget);
    });
  });
}
