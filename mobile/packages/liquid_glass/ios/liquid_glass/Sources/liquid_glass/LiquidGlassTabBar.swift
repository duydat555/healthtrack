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
/// iOS 26+: các phần tử nằm trong `GlassEffectContainer` nên kính hòa vào nhau.
struct LiquidGlassTabBarView: View {
    @ObservedObject var model: TabBarModel

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    tabs.glassEffect(.regular, in: .capsule)
                    if model.showsAdd { addButton.glassEffect(.regular.tint(model.tint).interactive(), in: .circle) }
                }
            }
            .padding(.horizontal, 4)
        } else {
            HStack(spacing: 12) {
                tabs.background(.ultraThinMaterial, in: Capsule())
                if model.showsAdd { addButton.background(model.tint, in: Circle()) }
            }
            .padding(.horizontal, 4)
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(model.items) { item in
                let isSelected = item.id == model.selected
                Button {
                    model.selected = item.id
                    model.onSelect(item.id)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol).font(.system(size: 20, weight: .semibold))
                        Text(item.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(isSelected ? model.tint : Color.secondary)
                    .background {
                        if isSelected { Capsule().fill(model.tint.opacity(0.16)) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .animation(.smooth(duration: 0.25), value: model.selected)
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
