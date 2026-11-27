// Sinh dữ liệu mẫu buổi tập cho test và cho các task làm song song (ảnh ghép, lịch sử, API).
// Dữ liệu TỔNG HỢP: đường đi theo các tuyến có thật ở Đà Nẵng, nhưng điểm GPS, tốc độ, độ cao và
// nhiễu được sinh bằng máy (hạt giống cố định nên chạy lại cho cùng kết quả).
//
//   cd mobile && dart run tool/gen_workout_fixtures.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_math.dart';

/// Đi qua các mốc [route] với tốc độ quanh [speed] (m/s), mỗi [stepS] giây một điểm.
/// [pauseAtM]: dừng [pauseS] giây khi qua quãng đường đó (đoạn mới sau khi dừng).
List<TrackPoint> walkRoute({
  required List<(double, double)> route,
  required double speed,
  required DateTime start,
  required int seed,
  double stepS = 2,
  double? pauseAtM,
  double pauseS = 30,
  double baseAlt = 8,
  double hill = 5,
}) {
  final rnd = math.Random(seed);
  final pts = <TrackPoint>[];
  var t = start, segment = 0, travelled = 0.0;
  var paused = false;
  for (var i = 1; i < route.length; i++) {
    final (lat1, lon1) = route[i - 1];
    final (lat2, lon2) = route[i];
    final legLen = haversine(lat1, lon1, lat2, lon2);
    var along = 0.0;
    while (along < legLen) {
      final f = along / legLen;
      final lat = lat1 + (lat2 - lat1) * f;
      final lon = lon1 + (lon2 - lon1) * f;
      // Nhiễu GPS khoảng ±2 m
      final nLat = (rnd.nextDouble() - 0.5) * 4 / 111320;
      final nLon =
          (rnd.nextDouble() - 0.5) *
          4 /
          (111320 * math.cos(lat * math.pi / 180));
      final v = speed * (0.9 + rnd.nextDouble() * 0.2);
      pts.add(
        TrackPoint(
          lat: lat + nLat,
          lon: lon + nLon,
          t: t,
          alt:
              baseAlt +
              hill * math.sin(travelled / 700) +
              (rnd.nextDouble() - 0.5),
          speed: v,
          accuracy: 4 + rnd.nextDouble() * 4,
          segment: segment,
        ),
      );
      along += v * stepS;
      travelled += v * stepS;
      t = t.add(Duration(milliseconds: (stepS * 1000).round()));
      if (!paused && pauseAtM != null && travelled >= pauseAtM) {
        paused = true;
        t = t.add(Duration(seconds: pauseS.round()));
        segment++;
      }
    }
  }
  final (lat, lon) = route.last;
  pts.add(
    TrackPoint(
      lat: lat,
      lon: lon,
      t: t,
      alt: baseAlt,
      speed: 0,
      accuracy: 5,
      segment: segment,
    ),
  );
  return pts;
}

Workout build(String id, Sport sport, String title, List<TrackPoint> pts) {
  final draft = Workout.fromPoints(
    id: id,
    sport: sport,
    points: pts,
    kcal: 0,
    title: title,
  );
  return draft.copyWith(
    kcal: workoutKcal(
      sport: sport,
      distanceM: draft.distanceM,
      movingSeconds: draft.movingSeconds,
      weightKg: 65,
    ),
  );
}

void main() {
  // Chạy 5 km ven sông Hàn (đường Bạch Đằng): từ cầu Rồng lên phía bắc rồi quay lại, dừng 30 giây ở điểm quay đầu
  const river = [
    (16.0607, 108.2265),
    (16.0655, 108.2253),
    (16.0720, 108.2244),
    (16.0790, 108.2237),
    (16.0830, 108.2236),
  ];
  final run = build(
    'sample-run-han-river',
    Sport.run,
    'Chạy ven sông Hàn',
    walkRoute(
      route: [
        ...river,
        for (final p in river.reversed.skip(1)) (p.$1, p.$2 + 0.00012),
      ],
      speed: 3.0,
      start: DateTime.utc(2026, 11, 21, 22, 30), // 5:30 sáng giờ Việt Nam
      seed: 1,
      pauseAtM: 2480,
    ),
  );

  // Đạp xe 10 km đường biển Võ Nguyên Giáp, đi rồi về
  const beach = [(16.0480, 108.2475), (16.0700, 108.2465), (16.0930, 108.2455)];
  final ride = build(
    'sample-ride-my-khe',
    Sport.ride,
    'Đạp xe biển Mỹ Khê',
    walkRoute(
      route: [
        ...beach,
        for (final p in beach.reversed.skip(1)) (p.$1, p.$2 + 0.00015),
      ],
      speed: 6.0,
      start: DateTime.utc(2026, 11, 22, 9, 45), // 16:45 chiều
      seed: 2,
      stepS: 3,
      baseAlt: 4,
      hill: 2,
    ),
  );

  // Đi bộ 2 km một vòng quanh khu VKU (đường Trần Đại Nghĩa)
  const campus = [
    (15.9750, 108.2525),
    (15.9750, 108.2572),
    (15.9705, 108.2572),
    (15.9705, 108.2525),
    (15.9750, 108.2525),
  ];
  final walk = build(
    'sample-walk-vku',
    Sport.walk,
    'Đi bộ quanh VKU',
    walkRoute(
      route: campus,
      speed: 1.35,
      start: DateTime.utc(2026, 11, 23, 11, 0),
      seed: 3,
      stepS: 3,
      baseAlt: 12,
      hill: 2,
    ),
  );

  final dir = Directory('test/fixtures/workouts')..createSync(recursive: true);
  const enc = JsonEncoder.withIndent(' ');
  for (final w in [run, ride, walk]) {
    File('${dir.path}/${w.id}.json')
        .writeAsStringSync('${enc.convert(w.toJson())}\n');
    stdout.writeln(
      '${w.id}: ${(w.distanceM / 1000).toStringAsFixed(2)} km, ${formatDuration(w.movingSeconds)}, '
      'nhịp ${formatPace(w.avgPaceSecPerKm)}/km, ${w.splits.length} split, ${w.points.length} điểm, '
      '${w.kcal.round()} kcal',
    );
  }
}
