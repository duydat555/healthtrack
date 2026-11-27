import CoreLocation
import Flutter
import UIKit

/// Ghi vị trí GPS cho buổi tập. Chỉ phát vị trí THÔ; lọc nhiễu, tạm dừng tự động và split nằm ở phía
/// Dart (thuần Dart nên test được bằng dữ liệu mẫu).
///
/// - Kênh phương thức `healthtrack/route`: `isAvailable`, `permission`, `requestPermission`,
///   `start`, `stop`, `lastKnown`.
/// - Kênh sự kiện `healthtrack/route/fixes`: mỗi vị trí là một map (lat, lon, alt, speed, acc, course, t).
///
/// Chạy nền cần khóa `UIBackgroundModes: location` trong Info.plist. Thiếu khóa này mà bật
/// `allowsBackgroundLocationUpdates` thì iOS làm app thoát, nên chỉ bật khi khóa có mặt.
public class RouteTrackerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var sink: FlutterEventSink?
    private var permissionResult: FlutterResult?
    private var tracking = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = RouteTrackerPlugin()
        let channel = FlutterMethodChannel(name: "healthtrack/route", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        FlutterEventChannel(name: "healthtrack/route/fixes", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance)
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(CLLocationManager.locationServicesEnabled())
        case "permission":
            result(permissionName(manager.authorizationStatus))
        case "requestPermission":
            requestPermission(result)
        case "start":
            let args = call.arguments as? [String: Any]
            start(activity: args?["activity"] as? String ?? "fitness", distanceFilter: args?["distanceFilter"] as? Double ?? 3)
            result(nil)
        case "stop":
            stop()
            result(nil)
        case "lastKnown":
            result(manager.location.map(encode))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: Quyền

    private func permissionName(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    /// Xin quyền "Khi dùng app". Đã có thì nâng lên "Luôn luôn" (iOS chỉ hỏi nâng cấp một lần) để
    /// buổi tập tiếp tục khi khóa máy.
    private func requestPermission(_ result: @escaping FlutterResult) {
        switch manager.authorizationStatus {
        case .notDetermined:
            permissionResult = result
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            permissionResult = result
            manager.requestAlwaysAuthorization()
            // iOS không phải lúc nào cũng gọi lại delegate khi người dùng bỏ qua hộp thoại nâng cấp
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.finishPermission() }
        default:
            result(permissionName(manager.authorizationStatus))
        }
    }

    private func finishPermission() {
        guard let r = permissionResult else { return }
        permissionResult = nil
        r(permissionName(manager.authorizationStatus))
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined { finishPermission() }
    }

    // MARK: Ghi vị trí

    private func start(activity: String, distanceFilter: Double) {
        manager.activityType = activity == "otherNavigation" ? .otherNavigation : .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = distanceFilter
        manager.pausesLocationUpdatesAutomatically = false
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        tracking = true
        manager.startUpdatingLocation()
    }

    private func stop() {
        tracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func encode(_ l: CLLocation) -> [String: Any] {
        var m: [String: Any] = [
            "lat": l.coordinate.latitude,
            "lon": l.coordinate.longitude,
            "acc": l.horizontalAccuracy,
            "t": Int(l.timestamp.timeIntervalSince1970 * 1000),
        ]
        if l.verticalAccuracy >= 0 { m["alt"] = l.altitude }
        if l.speed >= 0 { m["speed"] = l.speed }
        if l.course >= 0 { m["course"] = l.course }
        return m
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard tracking else { return }
        for l in locations { sink?(encode(l)) }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown chỉ là chưa có vị trí, iOS tự thử lại; các lỗi khác báo cho Dart
        if (error as? CLError)?.code == .locationUnknown { return }
        sink?(FlutterError(code: "location_failed", message: error.localizedDescription, details: nil))
    }

    // MARK: Luồng sự kiện

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
