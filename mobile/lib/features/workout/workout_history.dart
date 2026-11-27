import 'workout.dart';

/// Giữ thứ tự mới nhất trước do repository cung cấp. Null là tất cả các môn.
List<Workout> filterWorkouts(List<Workout> workouts, Sport? sport) =>
    sport == null
    ? workouts
    : workouts.where((workout) => workout.sport == sport).toList();

/// Tổng số mét từ đầu tuần (thứ Hai) và đầu tháng theo lịch địa phương.
/// Mỗi buổi được tính vào kỳ chứa thời điểm bắt đầu.
({double weekM, double monthM}) workoutDistanceTotals(
  Iterable<Workout> workouts, {
  required DateTime now,
}) {
  final local = now.toLocal();
  final weekStart = DateTime(
    local.year,
    local.month,
    local.day - local.weekday + DateTime.monday,
  );
  final monthStart = DateTime(local.year, local.month);
  var weekM = 0.0;
  var monthM = 0.0;
  for (final workout in workouts) {
    final start = workout.startedAt;
    if (start.isAfter(now)) continue;
    if (!start.isBefore(weekStart)) weekM += workout.distanceM;
    if (!start.isBefore(monthStart)) monthM += workout.distanceM;
  }
  return (weekM: weekM, monthM: monthM);
}
