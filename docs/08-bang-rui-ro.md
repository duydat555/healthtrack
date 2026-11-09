# Bảng theo dõi rủi ro

Xác suất (X) và Tác động (T): 1 thấp đến 5 cao. Điểm = X x T. Cập nhật ở đầu và cuối dự án (Risk Register Evolution).

| ID | Rủi ro | X | T | Điểm | Biện pháp | Chủ sở hữu | Trạng thái |
|---|---|---|---|---|---|---|---|
| R1 | Thành viên không đủ commit đều đặn, bị coi là dump commit | 3 | 5 | 15 | Chia issue nhỏ, nhắc trong họp, theo dõi commit hằng tuần | Đạt | Mở |
| R2 | Stakeholder chậm phản hồi hoặc đổi yêu cầu | 3 | 4 | 12 | Họp xác nhận định kỳ, quy trình Change Request | Đạt | Mở |
| R3 | Chỉ build iOS được trên Mac; thành viên không có Mac bị chặn | 3 | 4 | 12 | Phần Swift giao cho người có Mac; UI Flutter chạy được trên Android/macOS với bản dự phòng | Đạt | Mở |
| R9 | API Liquid Glass (iOS 26) thay đổi hoặc platform view gây giật | 2 | 3 | 6 | Bọc trong widget `LiquidGlass`, luôn có bản dự phòng `BackdropFilter`, đo FPS | Đạt | Mở |
| R10 | Chưa có tài khoản Apple Developer để phát hành TestFlight | 3 | 3 | 9 | Demo trên Simulator hoặc cài trực tiếp qua Xcode, có video dự phòng | Đạt | Mở |
| R4 | Hạ tầng cloud miễn phí ngủ đông hoặc giới hạn | 3 | 3 | 9 | Ping giữ thức, có Docker local và video demo dự phòng | Đạt | Mở |
| R5 | Rò rỉ dữ liệu người dùng hoặc secret | 2 | 5 | 10 | Không commit `.env`, kiểm tra quyền truy cập theo user, review bảo mật | Tân | Mở |
| R6 | Người dùng từ chối quyền thông báo iOS | 3 | 2 | 6 | Giải thích lý do trước khi xin quyền, có nhắc trong app | Tài | Mở |
| R7 | Xung đột merge khi nhiều người sửa chung | 3 | 2 | 6 | Nhánh nhỏ, PR ngắn, CODEOWNERS | Đạt | Mở |
| R8 | Thiếu thời gian vì lịch học các môn khác | 4 | 3 | 12 | Chia task nhỏ, ưu tiên P0 trước | Cả nhóm | Mở |

Phiên bản cập nhật sau lượt làm việc đầu tiên: cần bổ sung (rủi ro thực tế đã xảy ra và cách xử lý).
