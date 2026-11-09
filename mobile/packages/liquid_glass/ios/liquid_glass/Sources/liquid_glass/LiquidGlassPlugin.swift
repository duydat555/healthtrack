import Flutter
import UIKit

/// Plugin Liquid Glass: đăng ký platform view `healthtrack/liquid_glass`
/// và kênh `liquid_glass` để Dart hỏi máy có hỗ trợ Liquid Glass không.
/// Flutter tự gọi `register` qua GeneratedPluginRegistrant, không cần sửa AppDelegate.
public class LiquidGlassPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(LiquidGlassViewFactory(), withId: LiquidGlassViewFactory.viewType)

    let channel = FlutterMethodChannel(name: "liquid_glass", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiquidGlassPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "supportsLiquidGlass":
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
