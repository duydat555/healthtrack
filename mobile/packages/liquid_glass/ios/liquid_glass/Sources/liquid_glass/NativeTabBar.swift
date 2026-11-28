import Flutter
import UIKit

/// Thanh tab dùng `UITabBarController` thật của hệ thống (iOS 26+).
///
/// Thấu kính chọn tab, hiệu ứng nhấn giữ phình ra và kéo qua các tab, khúc xạ ở rìa kính, haptic,
/// trợ năng (VoiceOver, Giảm trong suốt, Giảm chuyển động) đều là hành vi có sẵn của hệ thống.
/// Tự vẽ bằng SwiftUI không tái tạo được những thứ này.
///
/// Nút thêm nhanh nằm GIỮA thanh, nổi lên phía trên mép thanh (kiểu nút giữa nổi của các app ví,
/// ngân hàng). Để thanh tab hệ thống chừa chỗ ở giữa, ta thêm một tab giữ chỗ không chọn được vào
/// vị trí giữa; nút kính phủ lên đúng vị trí đó. Chỉ số tab giữa Dart và hệ thống được đổi qua lại
/// bằng `nativeIndex` và `dartIndex`.
@available(iOS 26.0, *)
final class NativeTabBarContainer: UIView, UITabBarControllerDelegate {
    private let controller = UITabBarController()
    private let addButton = UIButton(type: .system)
    private let showsAdd: Bool
    private let channel: FlutterMethodChannel

    private static let addSize: CGFloat = 60
    private static let notchRadius: CGFloat = 38
    private static let notchRise: CGFloat = 2
    private let notchMask = CAShapeLayer()
    private let rim = CAShapeLayer()
    /// Vị trí của tab giữ chỗ (giữa các tab); nil khi không có nút thêm nhanh.
    private let slot: Int?
    /// Phần nút nhô lên phía trên thanh, Dart chừa sẵn chỗ này ở đầu platform view.
    private let bump: CGFloat

    init(frame: CGRect, params: [String: Any], channel: FlutterMethodChannel) {
        self.showsAdd = params["showsAdd"] as? Bool ?? true
        self.channel = channel
        let count = (params["items"] as? [[String: Any]] ?? []).count
        self.slot = showsAdd ? count / 2 : nil
        self.bump = CGFloat((params["bump"] as? Double) ?? 0)
        super.init(frame: frame)
        backgroundColor = .clear
        // tint: nền nút +; tabTint: icon và chữ tab đang chọn; onTint: glyph "+" trên nền tint
        let tint = (params["tint"] as? Int).map { UIColor(argb: $0) } ?? .systemYellow
        let tabTint = (params["tabTint"] as? Int).map { UIColor(argb: $0) } ?? tint
        let onTint = (params["onTint"] as? Int).map { UIColor(argb: $0) } ?? .white
        overrideUserInterfaceStyle = (params["dark"] as? Bool ?? false) ? .dark : .light

        let items = params["items"] as? [[String: Any]] ?? []
        var controllers = items.enumerated().map { index, raw -> UIViewController in
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            vc.tabBarItem = UITabBarItem(
                title: raw["title"] as? String ?? "",
                image: UIImage(systemName: raw["symbol"] as? String ?? "circle"),
                tag: index)
            return vc
        }
        if let slot {
            // Tab giữ chỗ: để trống, không chọn được, nút thêm nhanh phủ lên đây
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            vc.tabBarItem = UITabBarItem(title: " ", image: UIImage(), tag: -1)
            vc.tabBarItem.isEnabled = false
            controllers.insert(vc, at: slot)
        }
        controller.viewControllers = controllers
        controller.selectedIndex = nativeIndex(min(max(params["selected"] as? Int ?? 0, 0), max(items.count - 1, 0)))
        controller.delegate = self
        controller.view.backgroundColor = .clear
        controller.tabBar.tintColor = tabTint
        addSubview(controller.view)

        if showsAdd {
            layer.insertSublayer(rim, above: controller.view.layer)
            // Kính nổi bật (prominentGlass, giống nút chính khác trong app) màu vàng thương hiệu để nút
            // nổi rõ khi nhô lên trên nội dung; glyph dùng onTint (chữ đậm) để đọc rõ trên nền vàng.
            var config = UIButton.Configuration.prominentGlass()
            config.image = UIImage(
                systemName: "plus",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            )?.withTintColor(onTint, renderingMode: .alwaysOriginal)
            config.baseForegroundColor = onTint
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

    /// Chỉ số Dart -> chỉ số tab hệ thống (có tab giữ chỗ).
    private func nativeIndex(_ dart: Int) -> Int {
        guard let slot else { return dart }
        return dart >= slot ? dart + 1 : dart
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Đầu platform view dành cho phần nút nhô lên; thanh tab nằm phía dưới
        controller.view.frame = CGRect(x: 0, y: bump, width: bounds.width, height: bounds.height - bump)
        controller.view.layoutIfNeeded()
        // Nút + nằm giữa, tâm cách mép trên của viên kính một chút nên nhô lên khoảng nửa nút.
        // Thanh tab hệ thống tự đặt vị trí (có lề dưới) nên căn theo viên kính thật, không theo
        // platform view, nếu không hai bên sẽ lệch nhau.
        let capsule = tabBarCapsule()
        let top = capsule?.minY ?? bump
        // Tâm rãnh và tâm nút trùng nhau, cao hơn mép trên viên kính một chút
        let center = CGPoint(x: bounds.midX, y: top - Self.notchRise)
        addButton.frame = CGRect(
            x: center.x - Self.addSize / 2, y: center.y - Self.addSize / 2,
            width: Self.addSize, height: Self.addSize)
        if showsAdd { cutNotch(center: center, capsuleTop: top) }
    }

    /// Khoét một lỗ tròn ở giữa mép trên của thanh tab bằng mặt nạ, để lộ nội dung phía sau và ôm
    /// lấy nút `+`. Thanh vẫn là `UITabBar` thật nên giữ nguyên hiệu ứng thấu kính nảy của hệ thống;
    /// phần viền rãnh tự vẽ một nét mảnh thay cho viền kính bị cắt mất.
    private func cutNotch(center: CGPoint, capsuleTop: CGFloat) {
        let r = Self.notchRadius
        let local = CGPoint(x: center.x, y: center.y - controller.view.frame.minY)
        let path = UIBezierPath(rect: controller.view.bounds.insetBy(dx: -40, dy: -40))
        path.append(UIBezierPath(arcCenter: local, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        notchMask.frame = controller.view.bounds
        notchMask.path = path.cgPath
        notchMask.fillRule = .evenOdd
        controller.view.layer.mask = notchMask

        // Viền rãnh: phần cung nằm dưới mép trên của viên kính
        let a = asin(min(max((capsuleTop - center.y) / r, -1), 1))
        let arc = UIBezierPath(
            arcCenter: center, radius: r, startAngle: .pi - a, endAngle: a, clockwise: false)
        rim.path = arc.cgPath
        rim.strokeColor = UIColor.label.withAlphaComponent(0.18).cgColor
        rim.fillColor = nil
        rim.lineWidth = 1
        rim.frame = bounds
    }

    /// Khung viên kính thanh tab, theo hệ tọa độ của view này; nil nếu chưa dựng xong.
    /// Viên kính là view con rộng nhất, cao vừa phải (40 đến 100pt) trong thanh tab; chỉ dựa vào hình
    /// học, không dựa vào tên lớp riêng tư. Không thấy thì dùng khung hợp của hàng nút tab.
    private func tabBarCapsule() -> CGRect? {
        let bar = controller.tabBar
        var capsule: CGRect?
        var items: [CGRect] = []
        func walk(_ view: UIView) {
            for sub in view.subviews where !sub.isHidden && sub.alpha > 0 {
                let f = sub.convert(sub.bounds, to: self)
                if sub is UIControl, sub.bounds.height > 20, sub.bounds.width > 20 {
                    items.append(f)
                    continue
                }
                let wideEnough = f.width > bar.bounds.width * 0.6
                let tallEnough = f.height >= 40 && f.height <= 100
                let widest = f.width > (capsule?.width ?? 0)
                if wideEnough && tallEnough && widest { capsule = f }
                walk(sub)
            }
        }
        walk(bar)
        if let capsule { return capsule }
        guard !items.isEmpty else { return nil }
        return items.dropFirst().reduce(items[0]) { $0.union($1) }
    }

    /// Nền app đổi sáng/tối lúc đang chạy: kính và chữ đổi theo.
    func setDark(_ dark: Bool) {
        overrideUserInterfaceStyle = dark ? .dark : .light
    }

    /// Dart đổi tab (go_router): cập nhật hệ thống mà không báo ngược lại Dart.
    func setSelected(_ index: Int) {
        let native = nativeIndex(index)
        guard native != controller.selectedIndex, native < (controller.viewControllers?.count ?? 0) else { return }
        controller.selectedIndex = native
    }

    /// Tab giữ chỗ (nút + phủ lên) không chọn được.
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        viewController.tabBarItem.tag >= 0
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
            switch call.method {
            case "setSelected":
                if let index = call.arguments as? Int { container?.setSelected(index) }
                result(nil)
            case "setDark":
                if let dark = call.arguments as? Bool { container?.setDark(dark) }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }
}
