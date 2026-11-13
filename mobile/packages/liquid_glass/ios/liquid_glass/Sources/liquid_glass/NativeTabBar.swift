import Flutter
import UIKit

/// Thanh tab dùng `UITabBarController` thật của hệ thống (iOS 26+).
///
/// Thấu kính chọn tab, hiệu ứng nhấn giữ phình ra và kéo qua các tab, khúc xạ ở rìa kính, haptic,
/// trợ năng (VoiceOver, Giảm trong suốt, Giảm chuyển động) đều là hành vi có sẵn của hệ thống.
/// Tự vẽ bằng SwiftUI không tái tạo được những thứ này. Nút thêm nhanh là một nút kính riêng.
@available(iOS 26.0, *)
final class NativeTabBarContainer: UIView, UITabBarControllerDelegate {
    private let controller = UITabBarController()
    private let addButton = UIButton(type: .system)
    private let showsAdd: Bool
    private let channel: FlutterMethodChannel

    private static let addSize: CGFloat = 56
    private static let gap: CGFloat = 12

    init(frame: CGRect, params: [String: Any], channel: FlutterMethodChannel) {
        self.showsAdd = params["showsAdd"] as? Bool ?? true
        self.channel = channel
        super.init(frame: frame)
        backgroundColor = .clear
        let tint = (params["tint"] as? Int).map { UIColor(argb: $0) } ?? .systemRed
        overrideUserInterfaceStyle = (params["dark"] as? Bool ?? false) ? .dark : .light

        let items = params["items"] as? [[String: Any]] ?? []
        controller.viewControllers = items.enumerated().map { index, raw in
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            vc.tabBarItem = UITabBarItem(
                title: raw["title"] as? String ?? "",
                image: UIImage(systemName: raw["symbol"] as? String ?? "circle"),
                tag: index)
            return vc
        }
        controller.selectedIndex = min(max(params["selected"] as? Int ?? 0, 0), max(items.count - 1, 0))
        controller.delegate = self
        controller.view.backgroundColor = .clear
        controller.tabBar.tintColor = tint
        addSubview(controller.view)

        if showsAdd {
            var config = UIButton.Configuration.prominentGlass()
            config.image = UIImage(
                systemName: "plus",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
            config.baseForegroundColor = .white
            config.baseBackgroundColor = tint
            config.cornerStyle = .capsule
            addButton.configuration = config
            addButton.accessibilityLabel = "Thêm nhanh"
            addButton.addAction(UIAction { [weak self] _ in
                self?.channel.invokeMethod("onAdd", arguments: nil)
            }, for: .touchUpInside)
            addSubview(addButton)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let reserved = showsAdd ? Self.addSize + Self.gap : 0
        controller.view.frame = CGRect(x: 0, y: 0, width: bounds.width - reserved, height: bounds.height)
        addButton.frame = CGRect(
            x: bounds.width - Self.addSize, y: (bounds.height - Self.addSize) / 2,
            width: Self.addSize, height: Self.addSize)
    }

    /// Dart đổi tab (go_router): cập nhật hệ thống mà không báo ngược lại Dart.
    func setSelected(_ index: Int) {
        guard index != controller.selectedIndex, index < (controller.viewControllers?.count ?? 0) else { return }
        controller.selectedIndex = index
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        channel.invokeMethod("onSelect", arguments: viewController.tabBarItem.tag)
    }
}

@available(iOS 26.0, *)
final class NativeTabBarPlatformView: NSObject, FlutterPlatformView {
    private let container: NativeTabBarContainer

    init(frame: CGRect, params: [String: Any], channel: FlutterMethodChannel) {
        container = NativeTabBarContainer(frame: frame, params: params, channel: channel)
        super.init()
        channel.setMethodCallHandler { [weak container] call, result in
            if call.method == "setSelected", let index = call.arguments as? Int {
                container?.setSelected(index)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }
}
