# Definition of Done

Một task chỉ chuyển sang **Done** khi đạt tất cả:

- [ ] Đạt đủ Acceptance Criteria trong issue
- [ ] Code qua PR, có ít nhất 1 người khác duyệt (Peer Review Approval)
- [ ] CI xanh (lint, test, build)
- [ ] Có test cho phần mới (unit hoặc integration)
- [ ] Giao diện kiểm tra trên iOS Simulator (iPhone nhỏ, lớn; sáng, tối) nếu có sửa app
- [ ] Có migration Alembic (nếu đổi CSDL)
- [ ] Cập nhật tài liệu `docs/` liên quan
- [ ] Không có secret, dữ liệu thật trong commit
- [ ] PR ghi `Closes #<số-issue>`, issue được đóng và chuyển cột Done trên board
