import ActivityKit
import Flutter
import WidgetKit

/// Cầu nối Dart tới widget và Live Activity qua kênh `healthtrack/widget`:
/// - `saveSnapshot(json)`: ghi số liệu vào App Group rồi nhờ WidgetKit làm mới.
/// - `waterActivity({current, goal})`: bắt đầu hoặc cập nhật Live Activity uống nước.
/// - `endWaterActivity()`: kết thúc Live Activity.
/// - `workoutActivity({sport, movingSeconds, distanceM, paceSecPerKm?, paused})`: bắt đầu hoặc cập
///   nhật Live Activity buổi tập ngoài trời.
/// - `endWorkoutActivity()`: kết thúc Live Activity buổi tập.
final class WidgetBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "healthtrack/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "saveSnapshot":
        guard let json = call.arguments as? String, let data = json.data(using: .utf8) else {
          return result(FlutterError(code: "bad_args", message: "Thiếu JSON", details: nil))
        }
        UserDefaults(suiteName: AppGroup.id)?.set(data, forKey: AppGroup.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "waterActivity":
        guard let args = call.arguments as? [String: Int], let current = args["current"],
          let goal = args["goal"]
        else { return result(FlutterError(code: "bad_args", message: "Thiếu current/goal", details: nil)) }
        if #available(iOS 16.2, *) {
          Task { await updateWater(current: current, goal: goal); result(nil) }
        } else {
          result(nil)
        }
      case "endWaterActivity":
        if #available(iOS 16.2, *) {
          Task { await endWater(); result(nil) }
        } else {
          result(nil)
        }
      case "workoutActivity":
        guard let args = call.arguments as? [String: Any], let sport = args["sport"] as? String,
          let moving = args["movingSeconds"] as? Double, let dist = args["distanceM"] as? Double,
          let paused = args["paused"] as? Bool
        else { return result(FlutterError(code: "bad_args", message: "Thiếu số liệu buổi tập", details: nil)) }
        if #available(iOS 16.2, *) {
          let state = WorkoutActivityAttributes.ContentState(
            sport: sport, movingSeconds: moving, distanceM: dist,
            paceSecPerKm: args["paceSecPerKm"] as? Double, paused: paused, updatedAt: Date())
          Task { await updateWorkout(state); result(nil) }
        } else {
          result(nil)
        }
      case "endWorkoutActivity":
        if #available(iOS 16.2, *) {
          Task { await endWorkout(); result(nil) }
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 16.2, *)
  private static func updateWater(current: Int, goal: Int) async {
    let state = WaterActivityAttributes.ContentState(currentMl: current, goalMl: goal)
    let content = ActivityContent(state: state, staleDate: nil)
    if let running = Activity<WaterActivityAttributes>.activities.first {
      await running.update(content)
    } else if ActivityAuthorizationInfo().areActivitiesEnabled {
      _ = try? Activity.request(
        attributes: WaterActivityAttributes(), content: content, pushType: nil)
    }
    if current >= goal {  // đủ nước: giữ thêm 5 phút rồi tự biến mất
      for a in Activity<WaterActivityAttributes>.activities {
        await a.end(content, dismissalPolicy: .after(.now.addingTimeInterval(300)))
      }
    }
  }

  @available(iOS 16.2, *)
  private static func endWater() async {
    for a in Activity<WaterActivityAttributes>.activities {
      await a.end(nil, dismissalPolicy: .immediate)
    }
  }

  /// Cập nhật số liệu buổi tập. Quá 60 giây không có cập nhật (app bị tắt) thì hệ thống đánh dấu
  /// "cũ" để màn khóa nhắc mở app, thay vì đứng yên như đang chạy.
  @available(iOS 16.2, *)
  private static func updateWorkout(_ state: WorkoutActivityAttributes.ContentState) async {
    let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
    if let running = Activity<WorkoutActivityAttributes>.activities.first {
      await running.update(content)
    } else if ActivityAuthorizationInfo().areActivitiesEnabled {
      _ = try? Activity.request(
        attributes: WorkoutActivityAttributes(), content: content, pushType: nil)
    }
  }

  @available(iOS 16.2, *)
  private static func endWorkout() async {
    for a in Activity<WorkoutActivityAttributes>.activities {
      await a.end(nil, dismissalPolicy: .immediate)
    }
  }
}
