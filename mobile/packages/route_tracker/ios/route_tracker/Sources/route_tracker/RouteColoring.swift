import Flutter
import CoreLocation
import MapKit
import UIKit

/// Một điểm của đường đi gửi từ Dart: vĩ độ, kinh độ, tốc độ (m/s; âm là không rõ).
struct RoutePoint {
    let coordinate: CLLocationCoordinate2D
    let speed: Double
}

/// Giải mã mảng phẳng [lat, lon, speed, lat, lon, speed, ...] do Dart gửi (Float64List).
func decodeRoutePoints(_ any: Any?) -> [RoutePoint] {
    guard let data = (any as? FlutterStandardTypedData)?.data else { return [] }
    let count = data.count / MemoryLayout<Double>.size / 3
    var out: [RoutePoint] = []
    out.reserveCapacity(count)
    data.withUnsafeBytes { raw in
        let d = raw.bindMemory(to: Double.self)
        for i in 0..<count {
            out.append(RoutePoint(
                coordinate: CLLocationCoordinate2D(latitude: d[i * 3], longitude: d[i * 3 + 1]),
                speed: d[i * 3 + 2]))
        }
    }
    return out
}

func uiColor(argb: Int) -> UIColor {
    UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
}

/// Bảng màu chậm → nhanh. Mặc định đi từ cam đậm sang vàng nhạt (vàng là màu thương hiệu).
struct RoutePalette {
    let stops: [UIColor]

    static let `default` = RoutePalette(stops: [
        uiColor(argb: 0xFFFF5A1F), uiColor(argb: 0xFFFFB400), uiColor(argb: 0xFFFFE552),
    ])

    init(stops: [UIColor]) { self.stops = stops.isEmpty ? RoutePalette.default.stops : stops }

    init(argb: [Int]?) {
        self.init(stops: (argb ?? []).map(uiColor(argb:)))
    }

    /// Màu tại vị trí t trong [0, 1] bằng cách nội suy giữa các mốc.
    func color(at t: Double) -> UIColor {
        let clamped = min(max(t, 0), 1)
        if stops.count == 1 { return stops[0] }
        let scaled = clamped * Double(stops.count - 1)
        let i = min(Int(scaled), stops.count - 2)
        let f = CGFloat(scaled - Double(i))
        var a: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        stops[i].getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3)
        stops[i + 1].getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        return UIColor(
            red: a.0 + (b.0 - a.0) * f, green: a.1 + (b.1 - a.1) * f,
            blue: a.2 + (b.2 - a.2) * f, alpha: a.3 + (b.3 - a.3) * f)
    }
}

/// Làm mượt tốc độ bằng trung bình trượt ±[radius] điểm (khoảng 15 giây mỗi bên). Tốc độ từng
/// điểm dao động theo nhiễu GPS; không làm mượt thì màu đường đi lốm đốm thay vì chuyển dần.
/// Tốc độ không rõ (âm) lấy theo điểm trước, đầu chuỗi lấy điểm đầu tiên biết.
func smoothedSpeeds(_ points: [RoutePoint], radius: Int = 7) -> [Double] {
    var filled: [Double] = []
    var last = points.first(where: { $0.speed >= 0 })?.speed ?? 0
    for p in points {
        if p.speed >= 0 { last = p.speed }
        filled.append(last)
    }
    guard filled.count > 1 else { return filled }
    var prefix: [Double] = [0]
    for v in filled { prefix.append(prefix.last! + v) }
    return (0..<filled.count).map { i in
        let lo = max(0, i - radius), hi = min(filled.count - 1, i + radius)
        return (prefix[hi + 1] - prefix[lo]) / Double(hi - lo + 1)
    }
}

/// Chuẩn hóa tốc độ (đã làm mượt) về [0, 1] theo khoảng phân vị 10–90% của chính buổi tập, để
/// quãng chậm hay nhanh nổi bật dù tốc độ tuyệt đối khác nhau giữa người chạy và người đạp xe.
/// Khoảng quá hẹp (đều) trả 0,5 (màu giữa).
func normalizedSpeeds(_ points: [RoutePoint]) -> [Double] {
    guard points.contains(where: { $0.speed >= 0 }) else {
        return Array(repeating: 0.5, count: points.count)
    }
    let smooth = smoothedSpeeds(points)
    let sorted = smooth.sorted()
    guard sorted.count >= 2 else { return Array(repeating: 0.5, count: points.count) }
    let lo = sorted[Int(Double(sorted.count - 1) * 0.1)]
    let hi = sorted[Int(Double(sorted.count - 1) * 0.9)]
    guard hi - lo > 0.3 else { return Array(repeating: 0.5, count: points.count) }
    return smooth.map { min(max(($0 - lo) / (hi - lo), 0), 1) }
}

/// Vị trí (0–1) của từng điểm dọc theo chiều dài đường đi, dùng cho MKGradientPolylineRenderer.
func cumulativeFractions(_ points: [RoutePoint]) -> [Double] {
    guard points.count > 1 else { return points.map { _ in 0 } }
    var cum: [Double] = [0]
    for i in 1..<points.count {
        let a = CLLocation(latitude: points[i - 1].coordinate.latitude, longitude: points[i - 1].coordinate.longitude)
        let b = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
        cum.append(cum[i - 1] + a.distance(from: b))
    }
    let total = cum.last ?? 0
    return total <= 0 ? cum.map { _ in 0 } : cum.map { $0 / total }
}
