import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/workout/track_filter.dart';
import 'package:healthtrack/features/workout/tracking_session.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_math.dart';
import 'package:route_tracker/route_tracker.dart';

Workout fixture(String id) => Workout.fromJson(
  jsonDecode(File('test/fixtures/workouts/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

RawFix raw(TrackPoint p, {double? acc}) => RawFix(
  lat: p.lat,
  lon: p.lon,
  t: p.t,
  accuracy: acc ?? p.accuracy ?? 5,
  alt: p.alt,
  speed: p.speed,
);

/// Đường đứng yên: n vị trí cách nhau 1 giây tại cùng một chỗ.
List<RawFix> still(
  DateTime from,
  int seconds, {
  double lat = 16,
  double lon = 108,
}) => [
  for (var i = 0; i < seconds; i++)
    RawFix(
      lat: lat,
      lon: lon,
      t: from.add(Duration(seconds: i)),
      accuracy: 5,
      speed: 0.1,
    ),
];

/// Chiều dài đường THẬT của các tuyến trong `tool/gen_workout_fixtures.dart` (cộng các đoạn
/// thẳng giữa mốc). File mẫu dài hơn vì cộng thêm nhiễu GPS ±2 m; bộ lọc phải bám đường thật.
const trueDistanceM = {
  'sample-run-han-river': 5010.3,
  'sample-ride-my-khe': 10017.4,
  'sample-walk-vku': 2005.6,
};

void main() {
  group('TrackFilter', () {
    test('bỏ vị trí sai số lớn, sai số âm và thời gian đi lùi', () {
      final f = TrackFilter(Sport.run);
      final t = DateTime.utc(2026, 11, 20);
      expect(
        f.accept(RawFix(lat: 16, lon: 108, t: t, accuracy: 50), segment: 0),
        isNull,
      );
      expect(
        f.accept(RawFix(lat: 16, lon: 108, t: t, accuracy: -1), segment: 0),
        isNull,
      );
      expect(
        f.accept(RawFix(lat: 16, lon: 108, t: t, accuracy: 8), segment: 0),
        isNotNull,
      );
      expect(
        f.accept(RawFix(lat: 16, lon: 108, t: t, accuracy: 8), segment: 0),
        isNull,
      );
    });

    test('bỏ điểm nhảy 600 m trong 2 giây nhưng chấp nhận khi GPS định vị lại thật', () {
      final f = TrackFilter(Sport.run);
      final t0 = DateTime.utc(2026, 11, 20);
      f.accept(RawFix(lat: 16, lon: 108, t: t0, accuracy: 5), segment: 0);
      RawFix far(int s) => RawFix(
        lat: 16.0054,
        lon: 108,
        t: t0.add(Duration(seconds: s)),
        accuracy: 5,
      );
      expect(f.accept(far(2), segment: 0), isNull);
      expect(f.accept(far(3), segment: 0), isNull);
      expect(f.accept(far(4), segment: 0), isNull);
      // Sau 3 lần liên tiếp, coi là vị trí mới thật
      expect(f.accept(far(5), segment: 0), isNotNull);
    });

    test(
      'Kalman giảm độ nhiễu: điểm đứng yên rung ±4 m gần chỗ thật hơn điểm thô',
      () {
        final f = TrackFilter(Sport.walk);
        final t0 = DateTime.utc(2026, 11, 20);
        var rawErr = 0.0, filtErr = 0.0;
        const n = 60;
        for (var i = 0; i < n; i++) {
          final dx = (i.isEven ? 4 : -4) / 111320; // ±4 m theo kinh độ
          final r = RawFix(
            lat: 16,
            lon: 108 + dx,
            t: t0.add(Duration(seconds: i)),
            accuracy: 5,
          );
          final p = f.accept(r, segment: 0)!;
          if (i >= 10) {
            rawErr += haversine(16, 108, r.lat, r.lon);
            filtErr += haversine(16, 108, p.lat, p.lon);
          }
        }
        expect(filtErr, lessThan(rawErr * 0.6));
      },
    );
  });

  group('TrackingSession với buổi tập mẫu', () {
    for (final id in [
      'sample-run-han-river',
      'sample-ride-my-khe',
      'sample-walk-vku',
    ]) {
      test(
        '$id: quãng đường bám đường thật trong 2% và ngắn hơn bản nhiễu',
        () {
          final w = fixture(id);
          final s = TrackingSession(
            sport: w.sport,
            weightKg: 65,
            autoPause: false,
          )..start();
          for (final p in w.points) {
            s.onFix(raw(p));
          }
          final truth = trueDistanceM[id]!;
          expect(s.distanceM, closeTo(truth, truth * 0.02));
          // Làm mượt phải bớt phần quãng đường do nhiễu cộng thêm
          expect(s.distanceM, lessThan(w.distanceM));
          final out = s.finish(id: 'x')!;
          expect(out.sport, w.sport);
          expect(out.distanceM, closeTo(s.distanceM, 0.01));
          expect(out.splits.length, closeTo(w.splits.length, 1));
          // Calo tính từ quãng đường đã lọc, nên khớp với quãng đường THẬT chứ không phải bản nhiễu
          final expected = workoutKcal(
            sport: w.sport,
            distanceM: truth,
            movingSeconds: w.movingSeconds,
            weightKg: 65,
          );
          expect(out.kcal, closeTo(expected, expected * 0.04));
        },
      );
    }

    test('tiêm nhiễu (điểm nhảy 600 m, sai số 60 m) vẫn giữ quãng đường trong 2,5% so với đường thật', () {
      final w = fixture('sample-run-han-river');
      final s = TrackingSession(
        sport: Sport.run,
        weightKg: 65,
        autoPause: false,
      )..start();
      for (var i = 0; i < w.points.length; i++) {
        final p = w.points[i];
        if (i % 80 == 40) {
          // Điểm nhảy xa 600 m về phía đông
          s.onFix(
            RawFix(
              lat: p.lat,
              lon: p.lon + 0.0055,
              t: p.t,
              accuracy: 5,
              speed: 3,
            ),
          );
        } else if (i % 50 == 25) {
          s.onFix(raw(p, acc: 60));
        } else {
          s.onFix(raw(p));
        }
      }
      final truth = trueDistanceM['sample-run-han-river']!;
      expect(s.distanceM, closeTo(truth, truth * 0.025));
    });

    test('nhịp hiện tại gần nhịp thật của người chạy đều 3 m/s (5:33/km)', () {
      final w = fixture('sample-run-han-river');
      final s = TrackingSession(
        sport: Sport.run,
        weightKg: 65,
        autoPause: false,
      )..start();
      for (final p in w.points.take(150)) {
        s.onFix(raw(p));
      }
      expect(s.currentPaceSecPerKm(), closeTo(333, 40));
      expect(s.avgPaceSecPerKm, closeTo(333, 40));
    });
  });

  group('tạm dừng', () {
    test('đứng yên 10 giây thì tự tạm dừng; đi lại thì tự tiếp tục ở đoạn mới', () {
      final t0 = DateTime.utc(2026, 11, 20, 6);
      final s = TrackingSession(sport: Sport.run, weightKg: 65)..start();
      // 20 giây chạy 3 m/s
      for (var i = 0; i < 20; i++) {
        s.onFix(
          RawFix(
            lat: 16 + i * 3 / 111195,
            lon: 108,
            t: t0.add(Duration(seconds: i)),
            accuracy: 5,
            speed: 3,
          ),
        );
      }
      expect(s.state, SessionState.running);
      final moving = s.movingSeconds;
      // Đứng yên 15 giây
      final stopAt = t0.add(const Duration(seconds: 20));
      for (final f in still(stopAt, 15, lat: 16 + 60 / 111195)) {
        s.onFix(f);
      }
      expect(s.state, SessionState.paused);
      expect(s.pauseReason, PauseReason.auto);
      // Thời gian vận động chỉ tăng trong ~10 giây trước khi bị coi là đứng yên
      expect(s.movingSeconds - moving, lessThan(12));
      // Đi lại
      s.onFix(
        RawFix(
          lat: 16 + 70 / 111195,
          lon: 108,
          t: stopAt.add(const Duration(minutes: 2)),
          accuracy: 5,
          speed: 3,
        ),
      );
      expect(s.state, SessionState.running);
      expect(s.points.last.segment, 1);
    });

    test('không có vị trí mới 10 giây (CoreLocation ngừng báo khi đứng yên) cũng tự tạm dừng', () {
      final t0 = DateTime.utc(2026, 11, 20, 6);
      final s = TrackingSession(sport: Sport.walk, weightKg: 60)..start();
      s.onFix(RawFix(lat: 16, lon: 108, t: t0, accuracy: 5, speed: 1.3));
      s.tick(t0.add(const Duration(seconds: 5)));
      expect(s.state, SessionState.running);
      s.tick(t0.add(const Duration(seconds: 11)));
      expect(s.state, SessionState.paused);
    });

    test(
      'tạm dừng thủ công: bỏ qua vị trí cho tới khi người dùng bấm tiếp tục',
      () {
        final t0 = DateTime.utc(2026, 11, 20, 6);
        final s = TrackingSession(sport: Sport.run, weightKg: 65)..start();
        s.onFix(RawFix(lat: 16, lon: 108, t: t0, accuracy: 5, speed: 3));
        s.pause();
        expect(s.state, SessionState.paused);
        expect(s.pauseReason, PauseReason.manual);
        // Dù đang chạy nhanh, tạm dừng thủ công không tự tiếp tục
        expect(
          s.onFix(
            RawFix(
              lat: 16.001,
              lon: 108,
              t: t0.add(const Duration(seconds: 30)),
              accuracy: 5,
              speed: 4,
            ),
          ),
          isFalse,
        );
        expect(s.state, SessionState.paused);
        s.resume();
        expect(
          s.onFix(
            RawFix(
              lat: 16.0011,
              lon: 108,
              t: t0.add(const Duration(seconds: 40)),
              accuracy: 5,
              speed: 4,
            ),
          ),
          isTrue,
        );
        expect(s.points.last.segment, 1);
        // Hai đoạn không nối nhau: quãng giữa không được cộng
        expect(s.distanceM, 0);
      },
    );

    test('finish khi chưa có điểm nào trả về null', () {
      final s = TrackingSession(sport: Sport.run, weightKg: 65)..start();
      expect(s.finish(id: 'x'), isNull);
    });
  });
}
