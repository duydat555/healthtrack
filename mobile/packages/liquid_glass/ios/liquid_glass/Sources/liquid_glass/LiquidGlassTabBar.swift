import Flutter
import SwiftUI
import UIKit

/// Một mục của thanh tab: tên hiển thị và tên SF Symbol.
struct TabItem: Identifiable {
    let id: Int
    let title: String
    let symbol: String
}

final class TabBarModel: ObservableObject {
    @Published var items: [TabItem]
    @Published var selected: Int
    let tint: Color
    let tabTint: Color
    let onTint: Color
    let showsAdd: Bool
    /// Phần nút thêm nhanh nhô lên phía trên mép thanh (Dart chừa sẵn ở đầu platform view).
    let bump: CGFloat
    /// Lề an toàn dưới (home indicator): thanh kéo dài xuống sát đáy, các tab nằm phía trên lề này.
    let bottomInset: CGFloat
    var onSelect: (Int) -> Void = { _ in }
    var onAdd: () -> Void = {}

    init(
        items: [TabItem], selected: Int, tint: Color, tabTint: Color, onTint: Color, showsAdd: Bool,
        bump: CGFloat, bottomInset: CGFloat
    ) {
        self.items = items
        self.selected = selected
        self.tint = tint
        self.tabTint = tabTint
        self.onTint = onTint
        self.showsAdd = showsAdd
        self.bump = bump
        self.bottomInset = bottomInset
    }
}

/// Thân thanh tab trải hết chiều ngang, bo hai góc trên, có rãnh lõm tròn ở giữa mép trên để ôm
/// nút thêm nhanh nổi (kiểu thanh tab của các app ví, ngân hàng).
struct NotchedBarShape: Shape {
    var cornerRadius: CGFloat = 26
    var notchRadius: CGFloat = 38
    /// Tâm rãnh nằm cao hơn mép trên chừng này, nên rãnh sâu `notchRadius - notchRise`.
    var notchRise: CGFloat = 4
    var hasNotch: Bool = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = cornerRadius
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))

        if hasNotch {
            let cx = rect.midX
            let big = notchRadius
            let cy = rect.minY - notchRise
            // Giao điểm của đường tròn rãnh với mép trên: sin(phi) = notchRise / R (hệ y hướng xuống)
            let a = asin(notchRise / big)
            let dx = big * cos(a)
            let fillet: CGFloat = 16  // đoạn vê tròn nối mép phẳng vào rãnh cho mượt
            let delta: CGFloat = 0.30
            let left = CGFloat.pi - a - delta
            let right = a + delta
            func pt(_ phi: CGFloat) -> CGPoint {
                CGPoint(x: cx + big * cos(phi), y: cy + big * sin(phi))
            }
            p.addLine(to: CGPoint(x: cx - dx - fillet, y: rect.minY))
            p.addQuadCurve(to: pt(left), control: CGPoint(x: cx - dx, y: rect.minY))
            // Cung đi từ trái xuống đáy rồi sang phải (ngược chiều kim đồng hồ trên màn hình)
            p.addArc(
                center: CGPoint(x: cx, y: cy), radius: big,
                startAngle: .radians(Double(left)), endAngle: .radians(Double(right)), clockwise: true)
            p.addQuadCurve(
                to: CGPoint(x: cx + dx + fillet, y: rect.minY), control: CGPoint(x: cx + dx, y: rect.minY))
        }

        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Thanh tab dưới kiểu Liquid Glass: thanh kính trải ngang có rãnh lõm, nút thêm nhanh kính nhô lên ở
/// giữa. Tab đang chọn có một "thấu kính" kính nhỏ phía sau, dùng `glassEffectID` nên khi đổi tab
/// kính chảy từ tab cũ sang tab mới. Giảm trong suốt và Giảm chuyển động do hệ thống áp dụng cho kính.
struct LiquidGlassTabBarView: View {
    @ObservedObject var model: TabBarModel
    @Namespace private var glassNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let haptic = UISelectionFeedbackGenerator()

    private static let barHeight: CGFloat = 64
    private static let addSize: CGFloat = 60
    private static let notchRadius: CGFloat = 38

    private var spring: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)
    }

    private var split: Int { model.showsAdd ? model.items.count / 2 : model.items.count }
    private var shape: NotchedBarShape {
        NotchedBarShape(notchRadius: Self.notchRadius, hasNotch: model.showsAdd)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        let barTotal = Self.barHeight + model.bottomInset
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 6) {
                // Kính áp lên chính view chứa các tab để chữ và icon nằm TRÊN kính (kính của view anh em
                // cùng cấp trong container sẽ vẽ đè lên chữ)
                tabsRow(native: true)
                    .padding(.bottom, model.bottomInset)
                    .frame(maxWidth: .infinity)
                    .frame(height: barTotal, alignment: .top)
                    .glassEffect(.regular, in: shape)
                    .frame(height: barTotal + model.bump, alignment: .bottom)
                    .overlay(alignment: .top) { addButton(native: true) }
            }
        } else {
            ZStack(alignment: .bottom) {
                shape.fill(.ultraThinMaterial).frame(height: barTotal)
                tabsRow(native: false).padding(.bottom, model.bottomInset)
            }
            .frame(height: barTotal + model.bump, alignment: .bottom)
            .overlay(alignment: .top) { addButton(native: false) }
        }
    }

    private func tabsRow(native: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(model.items.prefix(split)) { tab($0, native: native) }
            if model.showsAdd { Color.clear.frame(width: Self.notchRadius * 2 - 4) }
            ForEach(model.items.dropFirst(split)) { tab($0, native: native) }
        }
        .padding(.horizontal, 8)
        .frame(height: Self.barHeight)
        .animation(spring, value: model.selected)
    }

    @ViewBuilder
    private func tab(_ item: TabItem, native: Bool) -> some View {
        let isSelected = item.id == model.selected
        Button {
            guard item.id != model.selected else { return }
            haptic.selectionChanged()
            model.selected = item.id
            model.onSelect(item.id)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? model.tabTint : Color.secondary)
                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected { lens(native: native) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Thấu kính của tab đang chọn.
    @ViewBuilder
    private func lens(native: Bool) -> some View {
        if #available(iOS 26.0, *), native {
            Capsule().fill(Color.clear)
                .glassEffect(.regular.tint(model.tabTint.opacity(0.14)), in: .capsule)
                .glassEffectID("lens", in: glassNS)
                .padding(.horizontal, 2)
        } else {
            Capsule().fill(model.tabTint.opacity(0.16)).padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func addButton(native: Bool) -> some View {
        if model.showsAdd {
            Button {
                model.onAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(model.onTint)
                    .frame(width: Self.addSize, height: Self.addSize)
            }
            .buttonStyle(.plain)
            .modifier(AddGlass(native: native, tint: model.tint))
            .accessibilityLabel("Thêm nhanh")
        }
    }
}

/// Nền nút thêm nhanh: kính nổi bật nhuộm vàng thương hiệu (iOS 26+), nền đặc ở máy cũ hơn.
private struct AddGlass: ViewModifier {
    let native: Bool
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), native {
            content.glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
            content.background(tint, in: Circle())
        }
    }
}

final class LiquidGlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/liquid_glass_tab_bar"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as? [String: Any] ?? [:]
        let items = (params["items"] as? [[String: Any]] ?? []).enumerated().map { index, raw in
            TabItem(id: index, title: raw["title"] as? String ?? "", symbol: raw["symbol"] as? String ?? "circle")
        }
        let channel = FlutterMethodChannel(name: "\(Self.viewType)/\(viewId)", binaryMessenger: messenger)
        let tint = (params["tint"] as? Int).map { Color(argb: $0) } ?? .yellow
        let tabTint = (params["tabTint"] as? Int).map { Color(argb: $0) } ?? tint
        let onTint = (params["onTint"] as? Int).map { Color(argb: $0) } ?? .white
        let model = TabBarModel(
            items: items,
            selected: params["selected"] as? Int ?? 0,
            tint: tint,
            tabTint: tabTint,
            onTint: onTint,
            showsAdd: params["showsAdd"] as? Bool ?? true,
            bump: CGFloat((params["bump"] as? Double) ?? 0),
            bottomInset: CGFloat((params["bottomInset"] as? Double) ?? 0)
        )
        model.onSelect = { channel.invokeMethod("onSelect", arguments: $0) }
        model.onAdd = { channel.invokeMethod("onAdd", arguments: nil) }
        let hosted = HostedPlatformView(
            frame: frame, rootView: LiquidGlassTabBarView(model: model), dark: params["dark"] as? Bool ?? false)
        // Dart báo tab đang chọn (khi đổi do go_router hoặc code) hoặc nền app đổi sáng/tối.
        channel.setMethodCallHandler { [weak hosted] call, result in
            switch call.method {
            case "setSelected":
                if let index = call.arguments as? Int {
                    DispatchQueue.main.async { model.selected = index }
                }
                result(nil)
            case "setDark":
                if let dark = call.arguments as? Bool {
                    DispatchQueue.main.async { hosted?.setDark(dark) }
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        return hosted
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
