# WBS và Từ điển WBS

## Quy tắc 100%
Tổng các gói con bằng đúng phạm vi của gói cha, không thiếu và không thừa. Mỗi gói lá (dòng có mã 2 chữ số như 3.2) ứng với **một hoặc hai Epic** trên GitHub, và mỗi Epic nằm đúng một gói lá. Nhờ vậy 15 Epic (80 task) phủ hết cây WBS và không có việc nào nằm ngoài WBS.

Cách kiểm tra: mọi Epic ở cột "Epic" trong từ điển bên dưới phải xuất hiện đúng một lần. Hiện có 15 Epic, đủ #1 đến #15.

## Cây WBS
```
1. HealthTrack
├── 1.0 Quản lý dự án
│   ├── 1.1 Điều lệ, WBS, rủi ro, Kanban               (Epic #1)
│   ├── 1.2 Quản lý thay đổi (Change Request, CCB)     (Epic #11)
│   └── 1.3 Báo cáo, slide, gói bằng chứng             (Epic #14)
├── 2.0 Hạ tầng và DevOps
│   ├── 2.1 Docker, CI/CD                              (Epic #2)
│   └── 2.2 Triển khai cloud HTTPS, bảo mật            (Epic #13)
├── 3.0 Backend (FastAPI)
│   ├── 3.1 Xác thực và hồ sơ người dùng               (Epic #3)
│   ├── 3.2 API chỉ số sức khỏe                        (Epic #4)
│   ├── 3.3 API mục tiêu và thuốc                      (Epic #5)
│   ├── 3.4 API thống kê                               (Epic #9)
│   └── 3.5 Nhắc nhở (backend và thông báo cục bộ)     (Epic #10)
├── 4.0 App iOS (Flutter + Swift)
│   ├── 4.1 Design system và điều hướng                (Epic #6)
│   ├── 4.2 Liquid Glass (Swift)                       (Epic #15)
│   ├── 4.3 Xác thực và ghi chỉ số                     (Epic #7)
│   └── 4.4 Dashboard và biểu đồ                       (Epic #8)
├── 5.0 Kiểm thử và chất lượng
│   └── 5.1 Test tự động, E2E, bảo mật                 (Epic #12)
└── 6.0 Nghiệm thu
    └── 6.1 UAT và đóng dự án                          (Epic #14, phần UAT)
```
Epic #14 gồm cả báo cáo/slide (1.3) và UAT (6.1). Task báo cáo, slide gắn vào 1.3, task UAT gắn vào 6.1.

## Từ điển WBS
Quy mô tính bằng story point (SP) cộng từ các task của Epic. Không đặt thời hạn, nhóm theo dõi bằng số task hoàn thành và velocity.

| Mã | Gói công việc | Mô tả | Sản phẩm bàn giao | Epic | Phụ trách chính (nhiều task nhất) | SP | Tiêu chí hoàn thành |
|---|---|---|---|---|---|---|---|
| 1.1 | Điều lệ, WBS, rủi ro, Kanban | Charter 13 mục, WBS, bảng rủi ro, CPM, Projects board | `docs/01`, `06`, `07`, `08`, board | #1 | Đạt | 30 | Charter có chữ ký PO và giảng viên; WBS đạt 100% Rule; board có 5 cột |
| 1.2 | Quản lý thay đổi | Quy trình CR, CCB, xử lý CR thật từ stakeholder | `docs/13`, issue CR | #11 | Đạt | 10 | Có ít nhất 1 CR thật, quyết định ghi rõ trong nhật ký |
| 1.3 | Báo cáo, slide, bằng chứng | Báo cáo 7 chương, slide 8-10 trang, gói bằng chứng 8 hạng mục | File báo cáo, slide, thư mục bằng chứng | #14 | Đạt | trong 38 | Nộp đủ hạng mục theo hướng dẫn học phần |
| 2.1 | Docker, CI/CD | Docker Compose, Makefile, workflow backend và mobile, template issue/PR | `docker-compose.yml`, `.github/` | #2 | Đạt | 18 | `make up` chạy được; CI xanh trên `main` |
| 2.2 | Triển khai cloud | Backend và CSDL lên Render, Neon; TestFlight; tự động deploy | URL HTTPS, bản TestFlight | #13 | Đạt | 16 | Gọi được API qua HTTPS; có link TestFlight hoặc video demo Simulator |
| 3.1 | Xác thực và hồ sơ | Đăng ký, đăng nhập JWT, refresh, `/users/me` | API và test | #3 | Tân | 26 | Đạt AC các task, test pass, không lộ mật khẩu |
| 3.2 | API chỉ số | CRUD cân nặng/BMI, nước, giấc ngủ, bước chân, bữa ăn | API và test | #4 | Tân, Tài | 27 | Mọi endpoint lọc theo user, test pass |
| 3.3 | API mục tiêu và thuốc | CRUD mục tiêu, thuốc | API và test | #5 | Đạt, Tân | 15 | Người dùng chỉ thấy dữ liệu của mình |
| 3.4 | API thống kê | Tổng hợp theo ngày/tuần/tháng, chỉ mục CSDL | API thống kê | #9 | Tân, Đạt | 13 | Truy vấn thống kê có chỉ mục, có test dữ liệu mẫu |
| 3.5 | Nhắc nhở | Model, API nhắc nhở, thông báo cục bộ trên app | API và màn hình nhắc nhở | #10 | Tài | 18 | Nhắc nhở hiện đúng giờ trên iOS |
| 4.1 | Design system | Theme, bộ widget nền, thanh điều hướng | Widget và màn hình demo | #6 | Thuận | 18 | Hiển thị đúng trên iPhone SE và Pro Max, sáng và tối |
| 4.2 | Liquid Glass (Swift) | Platform view SwiftUI `glassEffect`, thanh tab, container morph, bản dự phòng | Plugin `liquid_glass` | #15 | Đạt | 21 | Chạy đúng trên iOS 26, iOS cũ dùng bản dự phòng |
| 4.3 | Xác thực và ghi chỉ số | Màn hình đăng ký, đăng nhập, form ghi 6 loại chỉ số | Màn hình Flutter | #7 | Thuận | 31 | Luồng đăng ký, đăng nhập, ghi chỉ số chạy với backend thật |
| 4.4 | Dashboard | Biểu đồ xu hướng, so sánh mục tiêu, review hiệu năng | Màn hình Dashboard | #8 | Thuận | 21 | Biểu đồ đúng dữ liệu, cuộn mượt |
| 5.1 | Kiểm thử và chất lượng | Kế hoạch test, test tự động, E2E, review bảo mật | `docs/09`, test, báo cáo lỗi | #12 | Tài | 21 | Độ phủ backend từ 70%, E2E luồng chính pass |
| 6.1 | UAT và đóng dự án | Cho người dùng thử, ký biên bản, bài học kinh nghiệm | Biên bản UAT | #14 | Cả nhóm | trong 38 | Stakeholder ký biên bản hoặc email nghiệm thu |

Tổng cộng 323 SP trên 15 Epic, 80 task. Số SP của #14 (38) tính chung cho 1.3 và 6.1.
