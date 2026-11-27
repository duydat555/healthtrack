import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_math.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';

/// Đường thẳng hướng bắc dài [meters], tốc độ đều [speed] m/s, mỗi giây một điểm.
List<TrackPoint> straight(
  double meters, {
  double speed = 3,
  int segment = 0,
  DateTime? start,
  double startLat = 16.0,
  double? Function(int i)? alt,
}) {
  final t0 = start ?? DateTime.utc(2026, 11, 20, 23);
  final n = (meters / speed).round();
  return [
    for (var i = 0; i <= n; i++)
      TrackPoint(
        lat: startLat + i * speed / 111194.9,
        lon: 108.2,
        t: t0.add(Duration(seconds: i)),
        alt: alt?.call(i),
        segment: segment,
      ),
  ];
}

Workout fixture(String id) => Workout.fromJson(
  jsonDecode(File('test/fixtures/workouts/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

void main() {
  group('polyline', () {
    test('khớp ví dụ chuẩn của Google', () {
      const coords = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)];
      expect(encodePolyline(coords), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), coords);
    });
  });

  group('quãng đường, thời gian, split', () {
    test('một độ vĩ khoảng 111,2 km', () {
      expect(haversine(16, 108, 17, 108), closeTo(111195, 5));
    });

    test('2,5 km đều tốc độ: 3 split, split cuối 500 m', () {
      final pts = straight(2500);
      final splits = computeSplits(pts);
      expect(totalDistance(pts), closeTo(2500, 5));
      expect(splits.map((s) => s.index), [1, 2, 3]);
      expect(splits[0].distanceM, 1000);
      expect(splits[0].seconds, closeTo(333.3, 1));
      expect(splits[2].distanceM, closeTo(500, 5));
      expect(splits[0].paceSecPerKm, closeTo(333.3, 1));
    });

    test(
      'khoảng tạm dừng không tính vào quãng đường và thời gian vận động',
      () {
        final a = straight(1500);
        // Dừng 5 phút rồi chạy tiếp từ chỗ cũ, đoạn mới
        final b = straight(
          1500,
          segment: 1,
          start: a.last.t.add(const Duration(minutes: 5)),
          startLat: a.last.lat,
        );
        final pts = [...a, ...b];
        expect(totalDistance(pts), closeTo(3000, 10));
        expect(movingSeconds(pts), closeTo(1000, 2));
        final splits = computeSplits(pts);
        expect(splits.length, 3);
        // Split thứ 2 vắt qua lúc dừng nhưng không bị cộng 5 phút
        expect(splits[1].seconds, closeTo(333.3, 2));
      },
    );

    test('độ cao: nhiễu ±1 m không cộng, leo 10 m thì cộng', () {
      final noisy = straight(600, alt: (i) => 10 + (i.isEven ? 1 : -1));
      expect(elevationGain(noisy), 0);
      final climb = straight(600, alt: (i) => 10 + i * 0.05);
      // Cộng theo bậc ngưỡng 3 m: phần lẻ cuối dưới ngưỡng chưa được tính
      expect(elevationGain(climb), closeTo(10, 3));
    });
  });

  group('calo', () {
    test('chạy 1,0, đi bộ 0,5 kcal/kg/km; đạp xe theo MET', () {
      expect(
        workoutKcal(
          sport: Sport.run,
          distanceM: 5000,
          movingSeconds: 1800,
          weightKg: 60,
        ),
        300,
      );
      expect(
        workoutKcal(
          sport: Sport.walk,
          distanceM: 2000,
          movingSeconds: 1500,
          weightKg: 60,
        ),
        60,
      );
      // 20 km/h trong 1 giờ: 8 MET, ròng (8 - 1) × 60 × 1
      expect(
        workoutKcal(
          sport: Sport.ride,
          distanceM: 20000,
          movingSeconds: 3600,
          weightKg: 60,
        ),
        420,
      );
    });
  });

  group('định dạng', () {
    test('nhịp và thời lượng', () {
      expect(formatPace(330), '5:30');
      expect(formatPace(null), '--:--');
      expect(formatDuration(1670), '27:50');
      expect(formatDuration(3725), '1:02:05');
    });
  });

  group('dữ liệu mẫu', () {
    for (final id in [
      'sample-run-han-river',
      'sample-ride-my-khe',
      'sample-walk-vku',
    ]) {
      test(
        '$id: JSON giữ nguyên qua đọc và ghi, số liệu khớp với các điểm',
        () {
          final w = fixture(id);
          final again = Workout.fromJson(
            jsonDecode(jsonEncode(w.toJson())) as Map<String, Object?>,
          );
          expect(jsonEncode(again.toJson()), jsonEncode(w.toJson()));
          expect(totalDistance(w.points), closeTo(w.distanceM, 0.01));
          expect(movingSeconds(w.points), closeTo(w.movingSeconds, 0.01));
          expect(decodePolyline(w.polyline).length, w.points.length);
          expect(
            w.splits.fold<double>(0, (s, x) => s + x.distanceM),
            closeTo(w.distanceM, 1),
          );
        },
      );
    }

    test('buổi chạy mẫu có một lần tạm dừng', () {
      final w = fixture('sample-run-han-river');
      expect(w.sport, Sport.run);
      expect(w.points.map((p) => p.segment).toSet(), {0, 1});
      expect(
        w.endedAt.difference(w.startedAt).inSeconds,
        greaterThan(w.movingSeconds),
      );
    });
  });

  group('LocalWorkoutRepository', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('workouts'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('lưu, liệt kê mới nhất trước, đọc lại, xóa', () async {
      final repo = LocalWorkoutRepository(baseDir: () async => dir);
      final run = fixture('sample-run-han-river');
      final walk = fixture('sample-walk-vku');
      await repo.save(run);
      await repo.save(walk);
      expect((await repo.list()).map((w) => w.id), [walk.id, run.id]);
      expect((await repo.get(run.id))!.distanceM, run.distanceM);
      await repo.delete(run.id);
      expect((await repo.list()).map((w) => w.id), [walk.id]);
      expect(await repo.get(run.id), isNull);
    });

    test('từ chối id có ký tự lạ (không cho thoát ra ngoài thư mục)', () async {
      final repo = LocalWorkoutRepository(baseDir: () async => dir);
      expect(() => repo.get('../x'), throwsArgumentError);
    });
  });

  test('tên mặc định theo buổi trong ngày', () {
    expect(
      defaultTitle(Sport.run, DateTime(2026, 11, 22, 6)),
      'Chạy bộ buổi sáng',
    );
    expect(
      defaultTitle(Sport.ride, DateTime(2026, 11, 22, 19)),
      'Đạp xe buổi tối',
    );
  });
}
