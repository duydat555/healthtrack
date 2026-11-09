# Điều lệ dự án (Project Charter)

## 1. Thông tin chung
- **Tên dự án:** HealthTrack, ứng dụng theo dõi sức khỏe cá nhân
- **Học phần:** Quản trị dự án phần mềm, VKU. Giảng viên: TS. Nguyễn Thanh Tuấn
- **Nguồn đề tài:** Pathway 3, bài toán vận hành thực tế tại VKU
- **Stakeholder / Product Owner:** đại diện một CLB sinh viên VKU (cần bổ sung tên người, CLB và thông tin liên hệ)
- **Repo:** https://github.com/duydat555/healthtrack

## 2. Bối cảnh và vấn đề
Sinh viên ít theo dõi thói quen sức khỏe (ngủ, uống nước, vận động, ăn uống) vì dữ liệu nằm rải rác ở nhiều app, khó xem xu hướng và dễ quên. CLB cần một công cụ đơn giản để thành viên tự theo dõi và duy trì thói quen. (Cần xác nhận lại với stakeholder ở issue Phase 0.)

## 3. Giải pháp đề xuất
Ứng dụng iOS viết bằng Flutter, giao diện theo phong cách Liquid Glass của iOS 26 (phần hiệu ứng viết bằng Swift). Backend FastAPI chạy trên cloud. Người dùng ghi các chỉ số hằng ngày, xem biểu đồ xu hướng, đặt mục tiêu và nhận nhắc nhở.

## 4. Mục tiêu SMART
- Hoàn thành các chức năng lõi (đăng ký/đăng nhập, ghi 6 loại chỉ số, dashboard, nhắc nhở) và được stakeholder nghiệm thu.
- Độ phủ test backend từ 70% trở lên, CI xanh trên mọi PR merge vào `main`.
- Backend chạy thật qua HTTPS, app phân phối qua TestFlight, có ít nhất 10 người dùng thử trong đợt UAT.
- Mỗi thành viên có commit đều đặn và PR được review.

## 5. Phạm vi
**Trong phạm vi:** xác thực; CRUD cân nặng/BMI, nước, giấc ngủ, bước chân, bữa ăn, thuốc; mục tiêu; dashboard biểu đồ; nhắc nhở; app iOS (Flutter + Liquid Glass); triển khai backend lên cloud.
**Ngoài phạm vi (giai đoạn này):** kết nối thiết bị đeo và Apple Health, tư vấn y tế, thanh toán, phát hành App Store chính thức, phiên bản web.

## 6. Sản phẩm bàn giao
App iOS (bản TestFlight hoặc Simulator), backend chạy trên cloud (HTTPS), mã nguồn trên GitHub, bộ tài liệu trong `docs/`, gói bằng chứng 8 hạng mục.

## 7. Công cụ quản trị
GitHub Repository, Projects (cột Backlog / Ready / In Progress / In Review / Done), Issues, Pull Requests, Actions.

## 8. Phương pháp luận
Hybrid Scrum + Kanban: công việc chia thành các Phase, mỗi Phase gồm nhiều task trên bảng Kanban; một Phase kết thúc khi các task P0 xong và qua review. Không ràng buộc theo lịch cố định, theo dõi bằng số task hoàn thành và Velocity (story point hoàn thành mỗi lượt).

## 9. Rủi ro chính
Xem [08-bang-rui-ro.md](08-bang-rui-ro.md).

## 10. Vai trò
| Thành viên | Vai trò |
|---|---|
| Lê Duy Đạt | PM / Scrum Master + Tech Lead, kiêm Swift/iOS |
| Đặng Ngọc Tân | Backend Engineer |
| Huỳnh Thanh Thuận | Mobile Engineer (Flutter) |
| Nguyễn Văn Tài | QA & Test Engineer, module nhắc nhở |

## 11. Tiêu chí thành công và nghiệm thu
Stakeholder ký biên bản UAT hoặc gửi email nghiệm thu; các Acceptance Criteria của task P0 đều đạt.

## 12. Ràng buộc và giả định
Nhóm 4 người, dùng hạ tầng cloud miễn phí (Render, Neon/Supabase), không xử lý dữ liệu y tế thật. Build iOS cần máy Mac có Xcode.

## 13. Phê duyệt
Chữ ký Product Owner và giảng viên: cần bổ sung khi bản chính thức hoàn thành (issue Phase 0).
