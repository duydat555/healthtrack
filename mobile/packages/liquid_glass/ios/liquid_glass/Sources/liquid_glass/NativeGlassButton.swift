import Flutter
import UIKit

/// Nút Liquid Glass thật của hệ thống (iOS 26+): `UIButton` với `.glass()` hoặc `.prominentGlass()`.
///
/// Hiệu ứng nhấn đàn hồi, khúc xạ ở rìa, haptic và trợ năng là hành vi có sẵn của hệ thống.
/// Dart chỉ tạo view này khi máy hỗ trợ; nút icon (vòng tròn) dùng `symbol`, nút chính dùng `title`.
@available(iOS 26.0, *)
final class NativeGlassButtonPlatformView: NSObject, FlutterPlatformView {
    private let button = UIButton(type: .system)
    private let channel: FlutterMethodChannel
    private let prominent: Bool
    private let symbol: String?
    private let foreground: UIColor
    private let tint: UIColor
    private let onTint: UIColor
    private var title: String?

    init(frame: CGRect, params: [String: Any], channel: FlutterMethodChannel) {
        self.channel = channel
        prominent = params["prominent"] as? Bool ?? false
        symbol = params["symbol"] as? String
        title = params["title"] as? String
        foreground = (params["foreground"] as? Int).map { UIColor(argb: $0) } ?? .label
        tint = (params["tint"] as? Int).map { UIColor(argb: $0) } ?? .systemYellow
        onTint = (params["onTint"] as? Int).map { UIColor(argb: $0) } ?? .black
        super.init()

        button.overrideUserInterfaceStyle = (params["dark"] as? Bool ?? false) ? .dark : .light
        button.frame = CGRect(origin: .zero, size: frame.size)
        apply(enabled: params["enabled"] as? Bool ?? true, loading: params["loading"] as? Bool ?? false)
        button.addAction(UIAction { [weak self] _ in
            self?.channel.invokeMethod("onTap", arguments: nil)
        }, for: .touchUpInside)

        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update", let args = call.arguments as? [String: Any] else {
                return result(FlutterMethodNotImplemented)
            }
            if let newTitle = args["title"] as? String { self?.title = newTitle }
            self?.apply(enabled: args["enabled"] as? Bool ?? true, loading: args["loading"] as? Bool ?? false)
            result(nil)
        }
    }

    private func apply(enabled: Bool, loading: Bool) {
        var config = prominent ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        config.cornerStyle = .capsule
        config.baseForegroundColor = prominent ? onTint : foreground
        if prominent { config.baseBackgroundColor = tint }
        config.showsActivityIndicator = loading
        if let symbol {
            config.image = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        }
        if let title, !loading {
            // Lớp kính tự làm mờ chữ tiêu đề của UIButton.Configuration (kể cả khi đặt màu tường
            // minh), nên vẽ chữ thành ảnh giữ nguyên màu (alwaysOriginal), như glyph "+" của thanh tab.
            // VoiceOver đọc nhãn từ phía Dart nên không phụ thuộc vào ảnh này.
            config.image = titleImage(title, color: prominent ? onTint : foreground)
        }
        button.configuration = config
        // Đang tải vẫn để nút "bật" để giữ màu nhuộm; Dart chặn lượt bấm khi loading
        button.isEnabled = enabled
    }

    private func titleImage(_ text: String, color: UIColor) -> UIImage {
        let font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .headline).pointSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: ceil(size.width), height: ceil(size.height)))
        let image = renderer.image { _ in (text as NSString).draw(at: .zero, withAttributes: attrs) }
        return image.withRenderingMode(.alwaysOriginal)
    }

    func view() -> UIView { button }
}

final class LiquidGlassButtonFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/liquid_glass_button"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as? [String: Any] ?? [:]
        let channel = FlutterMethodChannel(name: "\(Self.viewType)/\(viewId)", binaryMessenger: messenger)
        if #available(iOS 26.0, *) {
            return NativeGlassButtonPlatformView(frame: frame, params: params, channel: channel)
        }
        // Dart không tạo view này khi iOS < 26; trả view rỗng để không bao giờ lỗi
        return EmptyPlatformView()
    }
}

private final class EmptyPlatformView: NSObject, FlutterPlatformView {
    func view() -> UIView { UIView() }
}
