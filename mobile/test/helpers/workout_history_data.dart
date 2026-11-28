import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_math.dart';

Workout historyWorkout(String id, Sport sport, DateTime start, double meters) =>
    Workout.fromJson({
      'id': id,
      'sport': sport.name,
      'title': 'Buổi mẫu $id',
      'startedAt': start.toUtc().toIso8601String(),
      'endedAt': start
          .add(const Duration(minutes: 15))
          .toUtc()
          .toIso8601String(),
      'movingSeconds': 900,
      'distanceM': meters,
      'polyline': encodePolyline([(16, 108), (16.01, 108.02), (16.02, 108.01)]),
    });
