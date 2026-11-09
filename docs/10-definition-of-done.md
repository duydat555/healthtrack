# Definition of Done

Một issue chỉ chuyển sang **Done** khi các tiêu chí áp dụng bên dưới được đánh dấu hoàn tất và có bằng chứng kiểm tra trong PR, CI hoặc issue. Với tiêu chí có điều kiện, nếu không áp dụng thì ghi rõ lý do trong PR thay vì bỏ qua không giải thích.

## Checklist kỹ thuật và sản phẩm

- [ ] Phạm vi PR khớp issue được giao; mọi Acceptance Criteria (AC) đều có thay đổi hoặc bằng chứng đáp ứng tương ứng. AC chưa rõ đã được xác nhận trước khi coi là đạt.
- [ ] Thay đổi tuân theo cấu trúc, quy ước và định dạng của repo; không có lỗi lint/format mới trong phần đã sửa.
- [ ] Test mới hoặc cập nhật bao phủ hành vi chính, trường hợp biên và lỗi phù hợp với thay đổi; test liên quan đã chạy và kết quả được ghi trong PR/CI.
- [ ] Không làm hỏng chức năng liên quan; bộ test/lint/build bắt buộc của CI hoàn tất thành công.
- [ ] Tài liệu trong `docs/` và hướng dẫn sử dụng được cập nhật khi hợp đồng API, hành vi, kiến trúc hoặc quy trình thay đổi.
- [ ] Không đưa secret, thông tin xác thực, dữ liệu sức khỏe thật hoặc dữ liệu cá nhân thật vào mã nguồn, fixture, log, ảnh hay commit.

## Checklist chỉ áp dụng khi có liên quan

- [ ] **Thay đổi CSDL:** có migration Alembic tương thích với head hiện tại; đã kiểm tra upgrade và, khi có thể, downgrade trên CSDL phát triển/test; model và schema được đăng ký đúng nơi.
- [ ] **Thay đổi giao diện:** đã kiểm tra trên iOS Simulator ở kích thước iPhone nhỏ và lớn, chế độ sáng và tối; ghi thiết bị/kết quả trong PR. Kiểm tra thiết bị thật nếu AC yêu cầu.
- [ ] **Thay đổi API:** tài liệu API/Swagger mô tả đúng endpoint, payload, phản hồi và lỗi; kiểm tra xác thực, phân quyền và quyền sở hữu dữ liệu khi endpoint thao tác dữ liệu người dùng.
- [ ] **Thay đổi cấu hình hoặc biến môi trường:** cập nhật `.env.example` nếu thêm biến; không lưu giá trị bí mật thật trong repo.
- [ ] **Thay đổi có tác động tới hiệu năng, bảo mật hoặc khả năng truy cập:** thực hiện các kiểm tra tương ứng với AC và lưu kết quả/bằng chứng trong PR.

## Checklist quy trình và phát hành

- [ ] Công việc nằm trên nhánh issue riêng tạo từ `main` mới nhất; PR chỉ bao gồm phạm vi issue đó.
- [ ] PR có mô tả thay đổi, loại thay đổi, kết quả tự kiểm thử và liên kết issue bằng `Closes #<số-issue>`.
- [ ] Có ít nhất một thành viên khác review và phê duyệt; các nhận xét cần xử lý đã được giải quyết hoặc có quyết định được ghi rõ.
- [ ] CI bắt buộc trên PR xanh (lint, test và build theo cấu hình repo).
- [ ] Sau khi merge, issue được đóng và chuyển sang cột **Done** trên GitHub Projects.

Không đánh dấu một tiêu chí là đạt chỉ dựa trên kế hoạch hoặc việc test source tồn tại; cần có kết quả chạy hay bằng chứng review tương ứng. Với thay đổi chỉ có tài liệu, ghi rõ các lệnh kiểm tra tài liệu đã chạy và nêu các kiểm tra code không áp dụng.
