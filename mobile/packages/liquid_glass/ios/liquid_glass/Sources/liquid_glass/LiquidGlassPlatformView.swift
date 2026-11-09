import Flutter
import SwiftUI
import UIKit

/// Factory để Flutter tạo view Liquid Glass qua `UiKitView(viewType: "healthtrack/liquid_glass")`.
final class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/liquid_glass"

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        makeLiquidGlassPlatformView(frame: frame, arguments: args as? [String: Any] ?? [:])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Lớp kính đơn: một hình chữ nhật bo góc, nội dung do Flutter vẽ phía trên.
func makeLiquidGlassPlatformView(frame: CGRect, arguments: [String: Any]) -> FlutterPlatformView {
    HostedPlatformView(
        frame: frame,
        rootView: LiquidGlassView(
            cornerRadius: arguments["cornerRadius"] as? Double ?? 24,
            tint: (arguments["tint"] as? Int).map { Color(argb: $0) },
            interactive: arguments["interactive"] as? Bool ?? false
        )
    )
}
