import ActivityKit
import Flutter
import WidgetKit

/// Cầu nối Dart tới widget và Live Activity qua kênh `healthtrack/widget`:
/// - `saveSnapshot(json)`: ghi số liệu vào App Group rồi nhờ WidgetKit làm mới.
/// - `waterActivity({current, goal})`: bắt đầu hoặc cập nhật Live Activity uống nước.
/// - `endWaterActivity()`: kết thúc Live Activity.
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
}
