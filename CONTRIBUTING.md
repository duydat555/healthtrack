# Hướng dẫn đóng góp

## Nhánh
- `main`: luôn chạy được, được bảo vệ (bắt buộc PR, 1 người duyệt, CI xanh).
- Nhánh làm việc: `feat/12-dang-nhap`, `fix/34-loi-bmi`, `docs/05-erd`, `test/20-auth`, `chore/03-ci`.

## Commit (Conventional Commits)
`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`. Ví dụ: `feat(auth): thêm endpoint đăng ký`.
Commit nhỏ, thường xuyên, mỗi commit một ý.

## Pull Request
- Tiêu đề theo Conventional Commits, mô tả có `Closes #<số-issue>`.
- Điền mục tự kiểm thử trong mẫu PR.
- Ít nhất 1 thành viên khác duyệt (không tự duyệt PR của mình).
- CI (lint, test, build) phải xanh trước khi merge. Dùng **Squash and merge**.

## Definition of Done
Xem [docs/10-definition-of-done.md](docs/10-definition-of-done.md).
