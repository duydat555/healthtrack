import Flutter
import SwiftUI
import UIKit

/// Factory để Flutter tạo view Liquid Glass qua `UiKitView(viewType: "healthtrack/liquid_glass")`.
final class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/liquid_glass"

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassPlatformView(frame: frame, arguments: args as? [String: Any] ?? [:])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
    private let host: UIHostingController<LiquidGlassView>

    init(frame: CGRect, arguments: [String: Any]) {
        let radius = arguments["cornerRadius"] as? Double ?? 24
        let interactive = arguments["interactive"] as? Bool ?? false
        var tint: Color?
        if let argb = arguments["tint"] as? Int {
            tint = Color(
                .sRGB,
                red: Double((argb >> 16) & 0xFF) / 255,
                green: Double((argb >> 8) & 0xFF) / 255,
                blue: Double(argb & 0xFF) / 255,
                opacity: Double((argb >> 24) & 0xFF) / 255
            )
        }
        host = UIHostingController(
            rootView: LiquidGlassView(cornerRadius: radius, tint: tint, interactive: interactive)
        )
        host.view.frame = frame
        host.view.backgroundColor = .clear
        super.init()
    }

    func view() -> UIView { host.view }
}
