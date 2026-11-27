import Flutter
import MapKit
import UIKit

/// Điểm đầu và điểm cuối của đường đi.
final class RouteAnnotation: NSObject, MKAnnotation {
    enum Kind { case start, finish }
    let kind: Kind
    dynamic var coordinate: CLLocationCoordinate2D
    init(kind: Kind, coordinate: CLLocationCoordinate2D) {
        self.kind = kind
        self.coordinate = coordinate
    }
}

/// Bản đồ Apple Maps (MKMapView) cho màn ghi hoạt động: vẽ đường đi đổi màu theo tốc độ, bám theo
/// người dùng, ghim điểm đầu và cuối. Điều khiển qua kênh `healthtrack/route_map/<id>`.
final class RouteMapPlatformView: NSObject, FlutterPlatformView, MKMapViewDelegate {
    private let map = MKMapView()
    private let channel: FlutterMethodChannel
    private var palette = RoutePalette.default
    private var points: [RoutePoint] = []
    private var casing: MKPolyline?
    private var line: MKPolyline?
    private var colors: [UIColor] = []
    private var locations: [CGFloat] = []
    private var startPin: RouteAnnotation?
    private var endPin: RouteAnnotation?

    init(frame: CGRect, params: [String: Any], channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        map.frame = frame
        map.delegate = self
        map.showsUserLocation = true
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        // Ẩn nhãn địa điểm: nền sạch để đường đi nổi bật như các app thể thao
        map.pointOfInterestFilter = MKPointOfInterestFilter.excludingAll
        map.overrideUserInterfaceStyle = (params["dark"] as? Bool ?? false) ? .dark : .light
        palette = RoutePalette(argb: params["gradient"] as? [Int])
        applyMapType(params["mapType"] as? String ?? "standard")
        if params["follow"] as? Bool ?? true { map.setUserTrackingMode(.follow, animated: false) }

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            self.handle(call, result)
        }
    }

    func view() -> UIView { map }

    private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "setRoute":
            points = decodeRoutePoints(args?["points"])
            rebuildRoute()
            result(nil)
        case "appendPoints":
            points += decodeRoutePoints(args?["points"])
            rebuildRoute()
            result(nil)
        case "setFollow":
            let on = args?["follow"] as? Bool ?? true
            map.setUserTrackingMode(on ? .follow : .none, animated: true)
            result(nil)
        case "recenter":
            map.setUserTrackingMode(.follow, animated: true)
            result(nil)
        case "fitRoute":
            fit(padding: args?["padding"] as? Double ?? 48)
            result(nil)
        case "setMapType":
            applyMapType(args?["mapType"] as? String ?? "standard")
            result(nil)
        case "setDark":
            map.overrideUserInterfaceStyle = (args?["dark"] as? Bool ?? false) ? .dark : .light
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Kiểu "muted" của iOS 16 làm nền nhạt đi và ẩn nhãn địa điểm để đường đi nổi bật như các app
    /// thể thao. Từ iOS 16 bộ lọc địa điểm phải đặt trên chính cấu hình bản đồ.
    private func applyMapType(_ name: String) {
        if #available(iOS 16.0, *) {
            switch name {
            case "satellite": map.preferredConfiguration = MKImageryMapConfiguration()
            case "hybrid":
                let c = MKHybridMapConfiguration()
                c.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = c
            default:
                let c = MKStandardMapConfiguration(emphasisStyle: .muted)
                c.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = c
            }
        } else {
            switch name {
            case "satellite": map.mapType = .satellite
            case "hybrid": map.mapType = .hybrid
            default: map.mapType = .standard
            }
        }
    }

    // MARK: Đường đi

    /// Bỏ bớt điểm màu để bộ vẽ chạy nhẹ với đường dài (tối đa khoảng 240 mốc màu).
    private func rebuildRoute() {
        if let c = casing { map.removeOverlay(c) }
        if let l = line { map.removeOverlay(l) }
        casing = nil; line = nil
        guard points.count >= 2 else { updatePins(); return }

        let coords = points.map(\.coordinate)
        let t = normalizedSpeeds(points)
        let frac = cumulativeFractions(points)
        let step = max(1, points.count / 240)
        var cols: [UIColor] = [], locs: [CGFloat] = []
        var lastFrac = -1.0
        for i in stride(from: 0, to: points.count, by: step) + [points.count - 1] {
            // Vị trí phải tăng dần; điểm trùng vị trí (đứng yên) thì bỏ
            if frac[i] <= lastFrac { continue }
            cols.append(palette.color(at: t[i]))
            locs.append(CGFloat(frac[i]))
            lastFrac = frac[i]
        }
        colors = cols
        locations = locs
        let outline = MKPolyline(coordinates: coords, count: coords.count)
        let main = MKPolyline(coordinates: coords, count: coords.count)
        casing = outline
        line = main
        // Viền tối vẽ trước, đường màu vẽ sau: đường vàng vẫn rõ trên nền bản đồ sáng
        map.addOverlay(outline, level: .aboveRoads)
        map.addOverlay(main, level: .aboveRoads)
        updatePins()
    }

    private func updatePins() {
        if let p = startPin { map.removeAnnotation(p); startPin = nil }
        if let p = endPin { map.removeAnnotation(p); endPin = nil }
        guard let first = points.first, points.count >= 2, let last = points.last else { return }
        startPin = RouteAnnotation(kind: .start, coordinate: first.coordinate)
        endPin = RouteAnnotation(kind: .finish, coordinate: last.coordinate)
        map.addAnnotation(startPin!)
        map.addAnnotation(endPin!)
    }

    private func fit(padding: Double) {
        guard let l = line else { return }
        map.setUserTrackingMode(.none, animated: false)
        let p = CGFloat(padding)
        map.setVisibleMapRect(
            l.boundingMapRect, edgePadding: UIEdgeInsets(top: p * 2, left: p, bottom: p * 4, right: p), animated: true)
    }

    // MARK: MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        if poly === casing {
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = UIColor(white: 0.08, alpha: 0.6)
            r.lineWidth = 10
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
        let r = MKGradientPolylineRenderer(polyline: poly)
        r.lineWidth = 6
        r.lineCap = .round
        r.lineJoin = .round
        r.setColors(colors, locations: locations)
        return r
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let a = annotation as? RouteAnnotation else { return nil }
        let id = a.kind == .start ? "start" : "finish"
        let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: a, reuseIdentifier: id)
        v.annotation = a
        v.markerTintColor = a.kind == .start ? .systemGreen : .black
        v.glyphImage = UIImage(systemName: a.kind == .start ? "play.fill" : "flag.checkered")
        v.glyphTintColor = .white
        v.displayPriority = .required
        return v
    }

    /// Người dùng kéo bản đồ thì iOS tự thoát chế độ bám: báo Dart để hiện nút định vị lại.
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        channel.invokeMethod("onFollow", arguments: mode != .none)
    }
}

final class RouteMapFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/route_map"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let channel = FlutterMethodChannel(name: "\(Self.viewType)/\(viewId)", binaryMessenger: messenger)
        return RouteMapPlatformView(frame: frame, params: args as? [String: Any] ?? [:], channel: channel)
    }
}
