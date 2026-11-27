import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/gamification/workout_badges.dart';
import 'package:healthtrack/features/workout/workout.dart';

Workout _workout(
  String id,
  DateTime startedAt,
  double distanceM, {
  Sport sport = Sport.run,
}) => Workout(
  id: id,
  sport: sport,
  title: 'Bài tập giả lập',
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(minutes: 30)),
  movingSeconds: 1800,
  distanceM: distanceM,
  elevationGainM: 0,
  kcal: 100,
  splits: const [],
  points: const [],
  polyline: '',
);

Map<String, bool> _earned(Iterable<Workout> workouts) => {
  for (final badge in workoutBadges(workouts)) badge.code: badge.earned,
};

void main() {
  group('huy hiệu workout', () {
    test('danh sách trống không đạt huy hiệu nào', () {
      expect(_earned([]).values, everyElement(isFalse));
    });

    test('buổi đầu tiên tính cả đi bộ nhưng huy hiệu cự ly chỉ tính chạy', () {
      final walk = _workout(
        'walk',
        DateTime(2026, 11, 23, 8),
        12000,
        sport: Sport.walk,
      );

      expect(_earned([walk]), {
        'workout_first': true,
        'run_5k': false,
        'run_10k': false,
        'run_week_20k': false,
      });
    });

    test('5 km yêu cầu một lần chạy đủ cự ly và ngưỡng bao gồm đúng 5 km', () {
      final monday = DateTime(2026, 11, 23, 8);
      final twoShortRuns = [
        _workout('a', monday, 2500),
        _workout('b', monday.add(const Duration(hours: 2)), 2500),
      ];
      expect(_earned(twoShortRuns)['run_5k'], isFalse);

      expect(_earned([_workout('exact', monday, 5000)])['run_5k'], isTrue);
      expect(_earned([_workout('short', monday, 4999.9)])['run_5k'], isFalse);
    });

    test('10 km cũng đạt huy hiệu 5 km', () {
      final earned = _earned([_workout('10k', DateTime(2026, 11, 23), 10000)]);
      expect(earned['run_5k'], isTrue);
      expect(earned['run_10k'], isTrue);
    });

    test(
      'tuần cộng nhiều lần chạy, tính từ thứ Hai và không cộng qua tuần',
      () {
        final monday = DateTime(2026, 11, 23, 8);
        final sameWeek = [
          _workout('mon', monday, 12000),
          _workout('wed', monday.add(const Duration(days: 2)), 8000),
        ];
        expect(_earned(sameWeek)['run_week_20k'], isTrue);

        final acrossWeeks = [
          _workout('sun', DateTime(2026, 11, 29, 8), 12000),
          _workout('next-mon', DateTime(2026, 11, 30, 8), 8000),
        ];
        expect(_earned(acrossWeeks)['run_week_20k'], isFalse);
      },
    );
  });
}
