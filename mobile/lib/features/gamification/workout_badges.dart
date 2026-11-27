import '../workout/workout.dart';
import 'models.dart';

/// Huy hiệu rút ra từ các workout đã lưu. 5 km/10 km là cự ly của một lần chạy;
/// huy hiệu tuần cộng các lần chạy từ thứ Hai đến Chủ nhật theo giờ địa phương.
List<Achievement> workoutBadges(Iterable<Workout> workouts) {
  final all = workouts.toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final runs = all.where((workout) => workout.sport == Sport.run).toList();

  DateTime? firstAt(List<Workout> candidates) =>
      candidates.isEmpty ? null : candidates.first.endedAt.toLocal();

  final firstRun5k = runs
      .where((workout) => workout.distanceM >= 5000)
      .toList();
  final firstRun10k = runs
      .where((workout) => workout.distanceM >= 10000)
      .toList();

  final weeklyTotals = <DateTime, double>{};
  final weeklyAwardDates = <DateTime, DateTime>{};
  for (final run in runs) {
    final started = run.startedAt.toLocal();
    final day = DateTime(started.year, started.month, started.day);
    final week = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final total = (weeklyTotals[week] ?? 0) + run.distanceM;
    weeklyTotals[week] = total;
    if (total >= 20000) {
      weeklyAwardDates.putIfAbsent(week, () => run.endedAt.toLocal());
    }
  }
  final first20kWeek = weeklyAwardDates.values.toList()..sort();

  return [
    Achievement(
      code: 'workout_first',
      title: 'Buổi đầu tiên',
      description: 'Hoàn thành buổi tập đầu tiên',
      earnedAt: firstAt(all),
    ),
    Achievement(
      code: 'run_5k',
      title: 'Chạy 5 km',
      description: 'Chạy ít nhất 5 km trong một buổi',
      earnedAt: firstAt(firstRun5k),
    ),
    Achievement(
      code: 'run_10k',
      title: 'Chạy 10 km',
      description: 'Chạy ít nhất 10 km trong một buổi',
      earnedAt: firstAt(firstRun10k),
    ),
    Achievement(
      code: 'run_week_20k',
      title: 'Tuần 20 km',
      description: 'Chạy tổng cộng ít nhất 20 km trong một tuần',
      earnedAt: first20kWeek.isEmpty ? null : first20kWeek.first,
    ),
  ];
}
