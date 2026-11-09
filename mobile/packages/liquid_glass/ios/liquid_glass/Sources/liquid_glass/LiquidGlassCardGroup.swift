import Flutter
import SwiftUI
import UIKit

struct GlassCardData: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let symbol: String
}

final class CardGroupModel: ObservableObject {
    @Published var cards: [GlassCardData]
    @Published var expandedId: String?
    let tint: Color?
    var onExpand: (String?) -> Void = { _ in }

    init(cards: [GlassCardData], tint: Color?) {
        self.cards = cards
        self.tint = tint
    }
}

/// Nhóm thẻ trong một `GlassEffectContainer`. Chạm thẻ để mở rộng: thẻ được chọn phóng to,
/// các thẻ còn lại co thành nút tròn, kính morph liền mạch nhờ `glassEffectID` cùng namespace.
struct LiquidGlassCardGroupView: View {
    @ObservedObject var model: CardGroupModel
    @Namespace private var glassSpace

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let expanded = model.cards.first(where: { $0.id == model.expandedId }) {
                HStack(spacing: 12) {
                    ForEach(model.cards.filter { $0.id != expanded.id }) { card in
                        compact(card)
                    }
                }
                full(expanded, isExpanded: true)
            } else {
                ForEach(model.cards) { card in full(card, isExpanded: false) }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func toggle(_ id: String) {
        let next = model.expandedId == id ? nil : id
        withAnimation(.bouncy(duration: 0.45)) { model.expandedId = next }
        model.onExpand(next)
    }

    private func full(_ card: GlassCardData, isExpanded: Bool) -> some View {
        Button { toggle(card.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: card.symbol).font(.title2.weight(.semibold))
                        .frame(width: 32) // cùng bề rộng để chữ các thẻ thẳng hàng
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title).font(.headline)
                        Text(card.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if isExpanded {
                    Text(card.detail).font(.body).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: isExpanded ? 260 : nil, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .modifier(GlassBackground(tint: model.tint, shape: .rect(cornerRadius: 24), id: card.id, space: glassSpace))
    }

    private func compact(_ card: GlassCardData) -> some View {
        Button { toggle(card.id) } label: {
            Image(systemName: card.symbol).font(.title3.weight(.semibold)).frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.title)
        .modifier(GlassBackground(tint: model.tint, shape: .circle, id: card.id, space: glassSpace))
    }
}

/// Nền kính + `glassEffectID` trên iOS 26+, vật liệu mờ trên bản cũ.
private struct GlassBackground<S: Shape>: ViewModifier {
    let tint: Color?
    let shape: S
    let id: String
    let space: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: shape)
                .glassEffectID(id, in: space)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

final class LiquidGlassCardGroupFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "healthtrack/liquid_glass_card_group"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as? [String: Any] ?? [:]
        let cards = (params["cards"] as? [[String: Any]] ?? []).map { raw in
            GlassCardData(
                id: raw["id"] as? String ?? UUID().uuidString,
                title: raw["title"] as? String ?? "",
                subtitle: raw["subtitle"] as? String ?? "",
                detail: raw["detail"] as? String ?? "",
                symbol: raw["symbol"] as? String ?? "circle"
            )
        }
        let model = CardGroupModel(cards: cards, tint: (params["tint"] as? Int).map { Color(argb: $0) })
        model.expandedId = params["expandedId"] as? String
        let channel = FlutterMethodChannel(name: "\(Self.viewType)/\(viewId)", binaryMessenger: messenger)
        model.onExpand = { channel.invokeMethod("onExpand", arguments: $0) }
        return HostedPlatformView(
            frame: frame, rootView: LiquidGlassCardGroupView(model: model), dark: params["dark"] as? Bool ?? false)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
