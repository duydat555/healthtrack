# Thiết kế giao diện

## Nguyên tắc
- Giao diện chính là **iPhone**, theo phong cách **app Fitness của Apple** kết hợp **Liquid Glass của iOS 26**: nền đen, thẻ xám đậm bo góc 20, màu nhấn rực cho từng chỉ số, vòng Activity Rings ở màn Tổng quan.
- Liquid Glass chỉ dùng cho lớp điều hướng và thẻ nổi bật (thanh tab, nút thêm nhanh, nhóm thẻ), không phủ kính toàn bộ nội dung (theo hướng dẫn của Apple). Thẻ nội dung thường là thẻ phẳng `AppColors.card`.
- Hiện chỉ có giao diện tối (`ThemeMode.dark`), giống Fitness. View kính native được ép vẽ ở chế độ tối (`dark: true`) để khớp nền.
- Màu, chữ, bo góc lấy từ `mobile/lib/core/theme.dart`, không hard-code trong màn hình. Dùng skill `baoyu-design` khi thiết kế.
- Hỗ trợ Dynamic Type, VoiceOver; kiểm tra trên iPhone SE và iPhone Pro Max.

## Màu chỉ số (cũng là màu của vòng Activity Rings)
| Chỉ số | Màu | Hex |
|---|---|---|
| Bước chân, màu thương hiệu | hồng đỏ | `#FA114F` |
| Giấc ngủ, thuốc (thẻ) | xanh chanh | `#A3F73B` |
| Nước uống | xanh lơ | `#1EEAEF` |
| Cân nặng | tím | `#BF5AF2` |
| Bữa ăn | cam | `#FF9F0A` |
| BMI | xanh dương | `#0A84FF` |

Nền `#000000`, thẻ `#1C1C1E`, chữ phụ `#8E8E93`.

## Thành phần dùng chung (`mobile/lib/widgets/`)
- `ActivityRings`: các vòng đồng tâm có hoạt ảnh chạy lên tiến độ; vòng đầu ở ngoài cùng.
- `MetricCard`: tên có màu nhấn, số lớn, đường xu hướng nhỏ.
- `SectionHeader`: tiêu đề mục chữ đậm kèm mũi tên.

Số liệu trên màn Tổng quan và Chỉ số hiện là **dữ liệu mẫu**, sẽ nối API ở Phase 3 và 4.

## Widget `LiquidGlass`
```dart
LiquidGlass(
  cornerRadius: 24,
  tint: AppColors.brand.withValues(alpha: 0.15),
  interactive: true,
  child: ...,
)
```
Trên iOS 26+ dùng lớp kính Swift native; nơi khác dùng `BackdropFilter`. Tránh dùng trong danh sách cuộn dài (mỗi thẻ là một platform view).

## Danh sách màn hình
| Tab | Màn hình |
|---|---|
| Trang chủ | Dashboard tóm tắt hôm nay, biểu đồ xu hướng |
| Ghi chỉ số | Cân nặng, nước, ngủ, bước chân, bữa ăn, thuốc |
| Nhắc nhở | Danh sách và form nhắc nhở |
| Hồ sơ | Thông tin cá nhân, mục tiêu, cài đặt |
| Ngoài tab | Onboarding, Đăng ký, Đăng nhập |

Wireframe chi tiết: cần bổ sung (issue Phase 0 của Thuận).

## Ảnh chụp thực tế
iPhone 13, iOS 27.2 Simulator.

Tổng quan (Activity Rings, thẻ chỉ số, thanh tab Liquid Glass):

![Tổng quan](images/liquid-glass-home.png)

Chỉ số (nhóm thẻ Liquid Glass, chạm để mở rộng và morph):

![Chỉ số](images/metrics-glass-cards.png)
