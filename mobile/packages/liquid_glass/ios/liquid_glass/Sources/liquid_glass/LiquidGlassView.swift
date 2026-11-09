import SwiftUI

/// View SwiftUI tạo hiệu ứng Liquid Glass (iOS 26+).
/// Flutter vẽ nội dung phía trên; view này chỉ vẽ lớp kính phía dưới.
struct LiquidGlassView: View {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    var body: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            // Dự phòng cho iOS cũ: vật liệu mờ chuẩn của hệ thống
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}
