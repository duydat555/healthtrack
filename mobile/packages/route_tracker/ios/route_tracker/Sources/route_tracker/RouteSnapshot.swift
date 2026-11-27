import Flutter
import MapKit
import UIKit

/// Ảnh bản đồ tĩnh của một buổi tập (MKMapSnapshotter) với đường đi đổi màu theo tốc độ vẽ lên.
/// Dùng cho trang tổng kết và ảnh ghép chia sẻ.
enum RouteSnapshot {
    static func render(_ args: [String: Any], completion: @escaping (FlutterStandardTypedData?, String?) -> Void) {
        let points = decodeRoutePoints(args["points"])
        guard points.count >= 2 else { return completion(nil, "Cần ít nhất 2 điểm") }
        let width = args["width"] as? Double ?? 1080
        let height = args["height"] as? Double ?? 1080
        let dark = args["dark"] as? Bool ?? false
        let mapType = args["mapType"] as? String ?? "standard"
        let palette = RoutePalette(argb: args["gradient"] as? [Int])
        // Độ rộng nét theo cạnh ngắn của ảnh để ảnh nhỏ hay lớn đều cân đối
        let lineWidth = CGFloat(args["lineWidth"] as? Double ?? (min(width, height) / 140))
        let pad = args["padding"] as? Double ?? 0.18

        // Khung bản đồ bao trọn đường đi, mở rộng cho khớp tỉ lệ ảnh và chừa lề
        var rect = MKMapRect.null
        for p in points { rect = rect.union(MKMapRect(origin: MKMapPoint(p.coordinate), size: MKMapSize(width: 0, height: 0))) }
        var w = max(rect.size.width, 600), h = max(rect.size.height, 600)
        let aspect = width / height
        if w / h < aspect { w = h * aspect } else { h = w / aspect }
        w *= 1 + pad * 2
        h *= 1 + pad * 2
        let center = MKMapPoint(x: rect.midX, y: rect.midY)
        let mapRect = MKMapRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)

        let options = MKMapSnapshotter.Options()
        options.mapRect = mapRect
        options.size = CGSize(width: width, height: height)
        options.scale = 1
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        options.showsBuildings = false
        // MKMapSnapshotter.Options.preferredConfiguration chỉ có từ iOS 17; bộ lọc địa điểm phải đặt
        // trên chính cấu hình (nhãn địa điểm làm rối ảnh chia sẻ)
        if #available(iOS 17.0, *) {
            switch mapType {
            case "satellite": options.preferredConfiguration = MKImageryMapConfiguration()
            case "hybrid":
                let c = MKHybridMapConfiguration()
                c.pointOfInterestFilter = .excludingAll
                options.preferredConfiguration = c
            default:
                let c = MKStandardMapConfiguration(emphasisStyle: .muted)
                c.pointOfInterestFilter = .excludingAll
                options.preferredConfiguration = c
            }
        } else {
            options.pointOfInterestFilter = .excludingAll
            options.mapType = mapType == "satellite" ? .satellite : (mapType == "hybrid" ? .hybrid : .standard)
        }

        MKMapSnapshotter(options: options).start(with: .global(qos: .userInitiated)) { snap, error in
            guard let snap else { return completion(nil, error?.localizedDescription ?? "Không tạo được ảnh bản đồ") }
            let t = normalizedSpeeds(points)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: snap.image.size, format: format).image { ctx in
                snap.image.draw(at: .zero)
                let g = ctx.cgContext
                g.setLineCap(.round)
                g.setLineJoin(.round)
                let pts = points.map { snap.point(for: $0.coordinate) }
                // Viền tối trước, rồi từng đoạn màu theo tốc độ
                g.setStrokeColor(UIColor(white: 0.06, alpha: 0.62).cgColor)
                g.setLineWidth(lineWidth * 1.7)
                g.beginPath()
                g.move(to: pts[0])
                for p in pts.dropFirst() { g.addLine(to: p) }
                g.strokePath()
                g.setLineWidth(lineWidth)
                for i in 1..<pts.count {
                    g.setStrokeColor(palette.color(at: (t[i - 1] + t[i]) / 2).cgColor)
                    g.beginPath()
                    g.move(to: pts[i - 1])
                    g.addLine(to: pts[i])
                    g.strokePath()
                }
                // Điểm đầu (xanh) và điểm cuối (đen) có viền trắng
                for (p, color) in [(pts.first!, UIColor.systemGreen), (pts.last!, UIColor.black)] {
                    let r = lineWidth * 1.6
                    g.setFillColor(UIColor.white.cgColor)
                    g.fillEllipse(in: CGRect(x: p.x - r - 2, y: p.y - r - 2, width: (r + 2) * 2, height: (r + 2) * 2))
                    g.setFillColor(color.cgColor)
                    g.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            }
            guard let png = image.pngData() else { return completion(nil, "Không mã hóa được ảnh") }
            completion(FlutterStandardTypedData(bytes: png), nil)
        }
    }
}
