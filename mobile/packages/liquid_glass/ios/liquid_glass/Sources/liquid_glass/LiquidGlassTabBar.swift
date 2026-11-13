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
    var onSelect: (Int) -> Void = { _ in }
    var onAdd: () -> Void = {}

    init(items: [TabItem], selected: Int, tint: Color, tabTint: Color, onTint: Color, showsAdd: Bool) {
        self.items = items
        self.selected = selected
        self.tint = tint
        self.tabTint = tabTint
        self.onTint = onTint
        self.showsAdd = showsAdd
    }
}

/// Thanh tab dưới kiểu Liquid Glass + nút thêm nhanh nổi.
///
/// iOS 26+: toàn bộ nằm trong một `GlassEffectContainer`. Thanh tab là một viên kính, tab đang
/// chọn là một "thấu kính" kính thứ hai dùng `glassEffectID` nên khi đổi tab, hệ thống tự làm kính
/// chảy và hòa từ vị trí cũ sang vị trí mới (không phải hoạt hình phóng to/làm mờ giả).
/// Các cài đặt Giảm trong suốt và Giảm chuyển động do hệ thống tự áp dụng cho kính; phần chuyển
/// động lò xo của ta tắt khi bật Giảm chuyển động.
struct LiquidGlassTabBarView: View {
    @ObservedObject var model: TabBarModel
    @Namespace private var glassNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fingerX: CGFloat?
    @State private var barHeight: CGFloat = 56
    @State private var barWidth: CGFloat = 1
    private let haptic = UISelectionFeedbackGenerator()

    private var spring: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 12) {
                    tabs(native: true)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("bar", in: glassNS)
                    if model.showsAdd {
                        addButton
                            .glassEffect(.regular.tint(model.tint).interactive(), in: .circle)
                            .glassEffectID("add", in: glassNS)
                    }
                }
            }
            .padding(.horizontal, 4)
        } else {
            HStack(spacing: 12) {
                tabs(native: false).background(.ultraThinMaterial, in: Capsule())
                if model.showsAdd { addButton.background(model.tint, in: Circle()) }
            }
            .padding(.horizontal, 4)
        }
    }

    private var itemWidth: CGFloat { max(barWidth - 8, 1) / CGFloat(max(model.items.count, 1)) }

    /// Tâm của thấu kính: bám ngón tay khi đang kéo (không vượt mép thanh), về giữa tab đang chọn
    /// khi không kéo.
    private var lensCenter: CGFloat {
        let half = itemWidth / 2
        if let x = fingerX { return min(max(x, 4 + half), barWidth - 4 - half) }
        return 4 + itemWidth * (CGFloat(model.selected) + 0.5)
    }

    /// Tab nằm dưới thấu kính; dùng để tô sáng icon và chữ.
    private var shownIndex: Int {
        min(max(Int((lensCenter - 4) / itemWidth), 0), max(model.items.count - 1, 0))
    }

    private var pressing: Bool { fingerX != nil }

    private func tabs(native: Bool) -> some View {
        ZStack(alignment: .leading) {
            // Thấu kính nằm dưới nhãn để icon và chữ luôn rõ
            lens(native: native)
            HStack(spacing: 0) {
                ForEach(model.items) { item in
                    tabLabel(item)
                }
            }
            .padding(4)
        }
        .background(
            GeometryReader { g in
                Color.clear.task(id: g.size.width) { barWidth = g.size.width; barHeight = g.size.height }
            }
        )
        .contentShape(Rectangle())
        // Nhấn giữ rồi kéo: thấu kính phình ra và chạy theo ngón tay (có haptic khi qua tab),
        // thả tay thì co lại vào tab gần nhất. Chạm nhanh cũng đi qua đây.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let before = shownIndex
                    fingerX = value.location.x
                    if shownIndex != before { haptic.selectionChanged() }
                }
                .onEnded { value in
                    let i = min(max(Int((value.location.x - 4) / itemWidth), 0), model.items.count - 1)
                    fingerX = nil
                    if i != model.selected {
                        model.selected = i
                        model.onSelect(i)
                    }
                }
        )
        .animation(pressing ? .interactiveSpring(response: 0.18, dampingFraction: 0.85) : spring, value: lensCenter)
        .animation(spring, value: pressing)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tabLabel(_ item: TabItem) -> some View {
        let isSelected = item.id == shownIndex
        VStack(spacing: 2) {
            // Icon mang màu thương hiệu; chữ dùng màu chính để đủ tương phản trên kính
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
        // Dưới thấu kính đang phình, nội dung tab được phóng to như qua kính lúp
        .scaleEffect(isSelected && pressing ? 1.18 : 1)
        .zIndex(isSelected ? 2 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.id == model.selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            model.selected = item.id
            model.onSelect(item.id)
        }
    }

    /// Một thấu kính duy nhất. iOS 26+: kính thật, phình to ra ngoài thanh khi nhấn giữ.
    @ViewBuilder
    private func lens(native: Bool) -> some View {
        let scale = pressing ? CGSize(width: 1.28, height: 1.2) : CGSize(width: 1, height: 1)
        Group {
            if #available(iOS 26.0, *), native {
                Capsule().fill(Color.clear)
                    .glassEffect(.regular.tint(model.tabTint.opacity(pressing ? 0.08 : 0.14)), in: .capsule)
            } else {
                Capsule().fill(model.tabTint.opacity(0.16))
            }
        }
        .frame(width: max(itemWidth - 2, 1), height: 48)
        .scaleEffect(scale)
        .offset(x: lensCenter - max(itemWidth - 2, 1) / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var addButton: some View {
        Button { model.onAdd() } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(model.onTint)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thêm nhanh")
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
        // iOS 26+: dùng UITabBar thật của hệ thống để có đủ hiệu ứng thấu kính của Apple
        if #available(iOS 26.0, *) {
            return NativeTabBarPlatformView(frame: frame, params: params, channel: channel)
        }
        let tint = (params["tint"] as? Int).map { Color(argb: $0) } ?? .yellow
        let tabTint = (params["tabTint"] as? Int).map { Color(argb: $0) } ?? tint
        let onTint = (params["onTint"] as? Int).map { Color(argb: $0) } ?? .white
        let model = TabBarModel(
            items: items,
            selected: params["selected"] as? Int ?? 0,
            tint: tint,
            tabTint: tabTint,
            onTint: onTint,
            showsAdd: params["showsAdd"] as? Bool ?? true
        )
        model.onSelect = { channel.invokeMethod("onSelect", arguments: $0) }
        model.onAdd = { channel.invokeMethod("onAdd", arguments: nil) }
        // Dart báo tab đang chọn (khi đổi do go_router hoặc code), cập nhật lại giao diện.
        channel.setMethodCallHandler { call, result in
            if call.method == "setSelected", let index = call.arguments as? Int {
                DispatchQueue.main.async { model.selected = index }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        return HostedPlatformView(
            frame: frame, rootView: LiquidGlassTabBarView(model: model), dark: params["dark"] as? Bool ?? false)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
