# WBS và Từ điển WBS

WBS tuân thủ quy tắc 100%: tổng các gói con bằng đúng phạm vi cha. Mỗi gói công việc tương ứng một Epic trên GitHub (xem tab Issues).

```
1. HealthTrack
├── 1.0 Quản lý dự án (Phase 0, 6)
│   ├── 1.1 Điều lệ, WBS, rủi ro
│   └── 1.2 Báo cáo, slide, gói bằng chứng
├── 2.0 Hạ tầng và DevOps (Phase 0, 5)
│   ├── 2.1 Docker, CI
│   └── 2.2 Triển khai backend HTTPS, phát hành TestFlight
├── 3.0 Backend (Phase 1, 2, 4)
│   ├── 3.1 Xác thực và hồ sơ
│   ├── 3.2 API chỉ số sức khỏe và mục tiêu
│   └── 3.3 Thống kê và nhắc nhở
├── 4.0 App iOS Flutter (Phase 3, 4)
│   ├── 4.1 Design system và điều hướng
│   ├── 4.2 Liquid Glass (Swift)
│   ├── 4.3 Xác thực và ghi chỉ số
│   ├── 4.4 Dashboard biểu đồ
│   └── 4.5 Nhắc nhở thông báo cục bộ
├── 5.0 Kiểm thử và chất lượng (Phase 0 đến 5)
│   ├── 5.1 Kế hoạch và test tự động
│   └── 5.2 E2E, bảo mật
└── 6.0 Nghiệm thu (Phase 6)
    └── 6.1 UAT và đóng dự án
```

## Từ điển WBS (mẫu)
| Mã | Gói công việc | Mô tả | Sản phẩm | Người phụ trách | Tiêu chí hoàn thành |
|---|---|---|---|---|---|
| 3.1 | Xác thực và hồ sơ | Đăng ký, đăng nhập JWT, refresh, hồ sơ | API + test | Tân | Đạt AC các task của Epic, test pass |
| 4.1 | Design system | Theme, bộ widget nền, điều hướng tab | Widget + màn hình demo | Thuận | Hiển thị đúng trên iPhone SE và Pro Max |
| 4.2 | Liquid Glass | Platform view SwiftUI glassEffect và bản dự phòng | Mã Swift + widget Dart | Đạt | Chạy đúng trên iOS 26 và iOS cũ |

Cần bổ sung đủ các gói còn lại ở issue Phase 0 "Hoàn thiện WBS và từ điển WBS".
