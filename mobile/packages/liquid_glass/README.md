# liquid_glass

Plugin Flutter cục bộ của HealthTrack, mang hiệu ứng **Liquid Glass** (SwiftUI `.glassEffect()`, iOS 26+) vào Flutter.

- `lib/liquid_glass.dart`: widget `LiquidGlass` và hàm `supportsLiquidGlass()`.
- `ios/liquid_glass/Sources/liquid_glass/`: mã Swift.
  - `LiquidGlassView.swift`: view SwiftUI vẽ lớp kính.
  - `LiquidGlassPlatformView.swift`: bọc view vào `UIHostingController` để Flutter nhúng qua `UiKitView`.
  - `LiquidGlassPlugin.swift`: đăng ký platform view và kênh `liquid_glass`.

Trên iOS dưới 26, Android hoặc khi chạy test, widget tự dùng bản dự phòng `BackdropFilter`.
Phụ trách: Lê Duy Đạt.
