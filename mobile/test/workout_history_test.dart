import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/workout/sample_workout_repository.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_history.dart';

import 'helpers/workout_history_data.dart';

void main() {
  test('lọc theo từng môn và giữ thứ tự mới nhất trước', () {
    final now = DateTime(2026, 11, 27);
    final workouts = [
      historyWorkout('run-1', Sport.run, now, 500),
      historyWorkout(
        'walk',
        Sport.walk,
        now.subtract(const Duration(days: 1)),
        500,
      ),
      historyWorkout(
        'run-2',
        Sport.run,
        now.subtract(const Duration(days: 2)),
        500,
      ),
      historyWorkout(
        'ride',
        Sport.ride,
        now.subtract(const Duration(days: 3)),
        500,
      ),
    ];
    expect(filterWorkouts(workouts, null), workouts);
    expect(filterWorkouts(workouts, Sport.run), [workouts[0], workouts[2]]);
    expect(filterWorkouts(workouts, Sport.walk), [workouts[1]]);
    expect(filterWorkouts(workouts, Sport.ride), [workouts[3]]);
    expect(filterWorkouts([workouts.first], Sport.ride), isEmpty);
  });

  test('tính từ đầu tuần và đầu tháng, tuần có thể vắt qua hai tháng', () {
    final now = DateTime(2026, 11, 1, 12); // Chủ nhật
    final workouts = [
      historyWorkout(
        'last-sun',
        Sport.run,
        DateTime(2026, 10, 25, 23, 59),
        8000,
      ),
      historyWorkout('mon', Sport.walk, DateTime(2026, 10, 26), 1250),
      historyWorkout('month-start', Sport.ride, DateTime(2026, 11, 1), 3500),
      historyWorkout('now', Sport.run, now, 750),
      historyWorkout(
        'future',
        Sport.walk,
        now.add(const Duration(seconds: 1)),
        4000,
      ),
    ];
    expect(workoutDistanceTotals(workouts, now: now), (
      weekM: 5500.0,
      monthM: 4250.0,
    ));
  });

  test('tổng tháng gồm buổi trước tuần này và danh sách rỗng có tổng 0', () {
    final now = DateTime(2026, 11, 27);
    final workout = historyWorkout(
      'prior-week',
      Sport.run,
      DateTime(2026, 11, 1),
      1200,
    );
    expect(workoutDistanceTotals([workout], now: now), (
      weekM: 0.0,
      monthM: 1200.0,
    ));
    expect(workoutDistanceTotals([], now: now), (weekM: 0.0, monthM: 0.0));
  });

  test('dữ liệu mẫu có đủ 3 môn, có lộ trình và đọc được chi tiết', () async {
    final repository = SampleWorkoutRepository.demo(DateTime(2026, 11, 27, 12));
    final workouts = await repository.list();
    expect(workouts.map((w) => w.sport), Sport.values);
    for (final workout in workouts) {
      expect(workout.polyline, isNotEmpty);
      expect(workout.distanceM, greaterThan(0));
      expect(await repository.get(workout.id), workout);
    }
  });
}
