import Flutter
import SwiftUI

extension Color {
    /// Chuyển giá trị ARGB 32-bit từ Dart (`Color.toARGB32()`) sang SwiftUI `Color`.
    init(argb: Int) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

/// Bọc một view SwiftUI thành `FlutterPlatformView` trong suốt, không có safe area.
final class HostedPlatformView<Content: View>: NSObject, FlutterPlatformView {
    private let host: UIHostingController<Content>

    init(frame: CGRect, rootView: Content, dark: Bool = false) {
        host = UIHostingController(rootView: rootView)
        host.view.frame = frame
        host.view.backgroundColor = .clear
        if dark { host.overrideUserInterfaceStyle = .dark }
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        super.init()
    }

    func view() -> UIView { host.view }
}
