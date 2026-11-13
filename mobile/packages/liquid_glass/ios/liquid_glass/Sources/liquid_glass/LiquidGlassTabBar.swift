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
    let showsAdd: Bool
    var onSelect: (Int) -> Void = { _ in }
    var onAdd: () -> Void = {}

    init(items: [TabItem], selected: Int, tint: Color, showsAdd: Bool) {
        self.items = items
        self.selected = selected
        self.tint = tint
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
    @State private var dragIndex: Int?
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

    /// Tab đang hiển thị là đang chọn: khi đang kéo thì là tab dưới ngón tay.
    private var shownIndex: Int { dragIndex ?? model.selected }

    private func index(at x: CGFloat) -> Int {
        let inner = max(barWidth - 8, 1)
        let i = Int((x - 4) / inner * CGFloat(model.items.count))
        return min(max(i, 0), model.items.count - 1)
    }

    private func tabs(native: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(model.items) { item in
                tabLabel(item, native: native)
            }
        }
        .padding(4)
        .background(
            GeometryReader { g in
                Color.clear.task(id: g.size.width) { barWidth = g.size.width }
            }
        )
        .contentShape(Rectangle())
        // Nhấn giữ rồi kéo qua các tab: thấu kính chạy theo ngón tay, thả tay mới chuyển tab.
        // Chạm nhanh cũng đi qua đây nên một cử chỉ lo cả hai trường hợp.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let i = index(at: value.location.x)
                    if i != dragIndex {
                        if dragIndex != nil { haptic.selectionChanged() }
                        dragIndex = i
                    }
                }
                .onEnded { value in
                    let i = index(at: value.location.x)
                    dragIndex = nil
                    if i != model.selected {
                        model.selected = i
                        model.onSelect(i)
                    }
                }
        )
        .animation(spring, value: shownIndex)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tabLabel(_ item: TabItem, native: Bool) -> some View {
        let isSelected = item.id == shownIndex
        VStack(spacing: 2) {
            // Icon mang màu thương hiệu; chữ dùng màu chính để đủ tương phản trên kính
            Image(systemName: item.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? model.tint : Color.secondary)
            Text(item.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background { lens(isSelected: isSelected, native: native) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.id == model.selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            model.selected = item.id
            model.onSelect(item.id)
        }
    }

    /// Thấu kính của tab đang chọn: kính thật (iOS 26+) hoặc viên màu nhạt (iOS cũ hơn).
    @ViewBuilder
    private func lens(isSelected: Bool, native: Bool) -> some View {
        if isSelected {
            if #available(iOS 26.0, *), native {
                Capsule().fill(Color.clear)
                    .glassEffect(.regular.tint(model.tint.opacity(0.14)), in: .capsule)
                    .glassEffectID("lens", in: glassNS)
            } else {
                Capsule().fill(model.tint.opacity(0.16))
            }
        }
    }

    private var addButton: some View {
        Button { model.onAdd() } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
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
        let tint = (params["tint"] as? Int).map { Color(argb: $0) } ?? .green
        let model = TabBarModel(
            items: items,
            selected: params["selected"] as? Int ?? 0,
            tint: tint,
            showsAdd: params["showsAdd"] as? Bool ?? true
        )
        let channel = FlutterMethodChannel(name: "\(Self.viewType)/\(viewId)", binaryMessenger: messenger)
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
