import CoreMotion
import Flutter
import UIKit

/// Cảm biến chuyển động của iPhone qua CoreMotion, không cần HealthKit (nên vẫn chạy khi app được
/// ký lại bằng AltStore/Sideloadly). Chỉ cần `NSMotionUsageDescription` trong Info.plist.
///
/// - `dailySteps`: tổng bước và quãng đường theo từng ngày (iPhone giữ khoảng 7 ngày gần nhất).
/// - `restIntervals`: các quãng máy nằm yên (stationary) từ lịch sử hoạt động, dùng để ước lượng giấc ngủ.
/// - Kênh sự kiện `healthtrack/activity/steps`: số bước từ đầu ngày, cập nhật trực tiếp khi đang đi.
public class ActivitySensorsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let pedometer = CMPedometer()
    private let activity = CMMotionActivityManager()
    private var sink: FlutterEventSink?
    private var liveDay: Date?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ActivitySensorsPlugin()
        let channel = FlutterMethodChannel(name: "healthtrack/activity", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        let events = FlutterEventChannel(name: "healthtrack/activity/steps", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(CMPedometer.isStepCountingAvailable())
        case "permission":
            result(permissionName(CMPedometer.authorizationStatus()))
        case "requestPermission":
            requestPermission(result)
        case "dailySteps":
            guard let (from, to) = range(call) else { return badArgs(result) }
            dailySteps(from, to, result)
        case "restIntervals":
            guard let (from, to) = range(call) else { return badArgs(result) }
            restIntervals(from, to, result)
        case "restAccess":
            // iOS dùng lịch sử chuyển động, quyền đi cùng quyền đếm bước
            result(true)
        case "openRestAccessSettings":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func range(_ call: FlutterMethodCall) -> (Date, Date)? {
        guard let args = call.arguments as? [String: Any],
              let fromMs = args["from"] as? Int, let toMs = args["to"] as? Int else { return nil }
        return (Date(timeIntervalSince1970: Double(fromMs) / 1000), Date(timeIntervalSince1970: Double(toMs) / 1000))
    }

    private func badArgs(_ result: FlutterResult) {
        result(FlutterError(code: "bad_args", message: "Thiếu from hoặc to", details: nil))
    }

    private func permissionName(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    /// iOS chỉ hỏi quyền khi lần đầu đọc dữ liệu, nên đọc thử 1 phút gần nhất để hiện hộp thoại.
    private func requestPermission(_ result: @escaping FlutterResult) {
        guard CMPedometer.isStepCountingAvailable() else { return result("unavailable") }
        let now = Date()
        pedometer.queryPedometerData(from: now.addingTimeInterval(-60), to: now) { [weak self] _, _ in
            DispatchQueue.main.async {
                result(self?.permissionName(CMPedometer.authorizationStatus()) ?? "denied")
            }
        }
    }

    private func dailySteps(_ from: Date, _ to: Date, _ result: @escaping FlutterResult) {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        var days: [(Date, Date)] = []
        var start = cal.startOfDay(for: from)
        while start < to {
            let next = cal.date(byAdding: .day, value: 1, to: start)!
            days.append((max(start, from), min(next, to)))
            start = next
        }
        var out: [[String: Any]] = []
        let lock = NSLock()
        let group = DispatchGroup()
        for (dayStart, dayEnd) in days {
            group.enter()
            pedometer.queryPedometerData(from: dayStart, to: dayEnd) { data, _ in
                if let data, data.numberOfSteps.intValue > 0 {
                    var row: [String: Any] = ["day": fmt.string(from: dayStart), "steps": data.numberOfSteps.intValue]
                    if let d = data.distance { row["distanceM"] = d.doubleValue }
                    lock.lock(); out.append(row); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            result(out.sorted { ($0["day"] as! String) < ($1["day"] as! String) })
        }
    }

    /// Quãng nằm yên = các bản ghi hoạt động liên tiếp có `stationary`, không phải đang đi xe,
    /// độ tin cậy từ trung bình trở lên. Mỗi bản ghi kéo dài tới lúc bản ghi kế tiếp bắt đầu.
    private func restIntervals(_ from: Date, _ to: Date, _ result: @escaping FlutterResult) {
        guard CMMotionActivityManager.isActivityAvailable() else { return result([]) }
        activity.queryActivityStarting(from: from, to: to, to: .main) { items, error in
            if let error {
                return result(FlutterError(code: "query_failed", message: error.localizedDescription, details: nil))
            }
            let list = items ?? []
            var out: [[String: Any]] = []
            var openStart: Date?
            for (i, a) in list.enumerated() {
                let end = i + 1 < list.count ? list[i + 1].startDate : to
                let resting = a.stationary && !a.automotive && a.confidence != .low
                if resting {
                    if openStart == nil { openStart = a.startDate }
                } else if let s = openStart {
                    out.append(["start": Int(s.timeIntervalSince1970 * 1000),
                                "end": Int(a.startDate.timeIntervalSince1970 * 1000)])
                    openStart = nil
                }
                if i + 1 == list.count, let s = openStart {
                    out.append(["start": Int(s.timeIntervalSince1970 * 1000),
                                "end": Int(end.timeIntervalSince1970 * 1000)])
                }
            }
            result(out)
        }
    }

    // MARK: Bước chân trực tiếp

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        startLive()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        pedometer.stopUpdates()
        sink = nil
        return nil
    }

    /// Đếm từ đầu ngày; sang ngày mới thì bắt đầu lại để số không cộng dồn qua đêm.
    private func startLive() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let today = Calendar.current.startOfDay(for: Date())
        liveDay = today
        pedometer.stopUpdates()
        pedometer.startUpdates(from: today) { [weak self] data, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async {
                if Calendar.current.startOfDay(for: Date()) != self.liveDay {
                    self.startLive()
                    return
                }
                self.sink?(data.numberOfSteps.intValue)
            }
        }
    }
}
