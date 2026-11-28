import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widget/widget_bridge.dart';
import 'workout.dart';

/// Hiện số liệu buổi tập trên màn hình khóa và Dynamic Island (Live Activity, iOS 16.2+).
/// Mọi lỗi đều bị nuốt ở phía cầu nối: không có Live Activity thì buổi tập vẫn ghi bình thường.
abstract class WorkoutActivity {
  Future<void> update({
    required Sport sport,
    required double movingSeconds,
    required double distanceM,
    required double? paceSecPerKm,
    required bool paused,
  });

  Future<void> end();
}

class BridgeWorkoutActivity implements WorkoutActivity {
  const BridgeWorkoutActivity(this._bridge);

  final WidgetBridge _bridge;

  @override
  Future<void> update({
    required Sport sport,
    required double movingSeconds,
    required double distanceM,
    required double? paceSecPerKm,
    required bool paused,
  }) => _bridge.workoutActivity(
    sport: sport.name,
    movingSeconds: movingSeconds,
    distanceM: distanceM,
    paceSecPerKm: paceSecPerKm,
    paused: paused,
  );

  @override
  Future<void> end() => _bridge.endWorkoutActivity();
}

final workoutActivityProvider = Provider<WorkoutActivity>(
  (ref) => BridgeWorkoutActivity(ref.watch(widgetBridgeProvider)),
);
