import 'workout.dart';
import 'workout_repository.dart';

/// Repository dùng trong phiên debug hoặc test, với các lộ trình tổng hợp.
class SampleWorkoutRepository implements WorkoutRepository {
  SampleWorkoutRepository(Iterable<Workout> workouts)
    : _workouts = {for (final workout in workouts) workout.id: workout};

  factory SampleWorkoutRepository.demo(DateTime now) {
    const routes = [
      (
        'demo-run',
        Sport.run,
        'Chạy quanh công viên',
        Duration(minutes: 35),
        300.0,
        [
          (16.001, 108.001),
          (16.009, 108.004),
          (16.014, 108.012),
          (16.006, 108.017),
          (16.001, 108.001),
        ],
      ),
      (
        'demo-walk',
        Sport.walk,
        'Đi bộ buổi chiều',
        Duration(days: 2),
        85.0,
        [
          (16.017, 108.013),
          (16.020, 108.014),
          (16.025, 108.011),
          (16.021, 108.005),
          (16.017, 108.013),
        ],
      ),
      (
        'demo-ride',
        Sport.ride,
        'Đạp xe ven biển',
        Duration(days: 8),
        330.0,
        [
          (16.034, 108.240),
          (16.043, 108.246),
          (16.060, 108.247),
          (16.079, 108.252),
          (16.103, 108.261),
        ],
      ),
    ];
    return SampleWorkoutRepository([
      for (final (id, sport, title, age, kcal, track) in routes)
        Workout.fromPoints(
          id: id,
          sport: sport,
          title: title,
          kcal: kcal,
          points: [
            for (final (index, (lat, lon)) in track.indexed)
              TrackPoint(
                lat: lat,
                lon: lon,
                t: now.subtract(age).add(Duration(minutes: index * 7)),
                alt: 5.0 + index * 3,
              ),
          ],
        ),
    ]);
  }

  final Map<String, Workout> _workouts;

  @override
  Future<List<Workout>> list() async =>
      _workouts.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<Workout?> get(String id) async => _workouts[id];

  @override
  Future<void> save(Workout workout) async => _workouts[workout.id] = workout;

  @override
  Future<void> delete(String id) async => _workouts.remove(id);
}
