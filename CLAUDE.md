# CLAUDE.md

Đọc [AGENTS.md](AGENTS.md) trước: đó là quy tắc chung của dự án. Phần dưới là ghi chú riêng cho Claude Code.

## Ngôn ngữ
Trả lời và viết mọi tài liệu (README, docs, nội dung issue/PR) bằng **tiếng Việt**. Giữ tiếng Anh cho thuật ngữ kỹ thuật, tên code và commit message.

## Skill nên dùng
- **baoyu-design**: dùng khi thiết kế hoặc làm đẹp giao diện app (màn hình, widget, bố cục). Cài skill trên máy của bạn trước khi dùng; nếu chưa có thì bám theo `mobile/lib/core/theme.dart` và `docs/05-thiet-ke-giao-dien.md`.
- **code-review**: chạy trước khi mở PR để bắt lỗi sớm.

## Gợi ý làm việc
- Bắt đầu bằng việc đọc issue và `docs/` liên quan, rồi mới sửa code.
- App chạy trên iOS Simulator: `make up` (backend) rồi `make mobile`. Có thể dùng `xcrun simctl io booted screenshot` để chụp màn hình kiểm tra giao diện.
- Giao diện theo phong cách iOS 26 Liquid Glass. Dùng widget `LiquidGlass`; nếu cần tính năng kính mới (morph, container) thì sửa phía Swift trong plugin `mobile/packages/liquid_glass/`.
- Sau khi sửa, chạy `make test`, `make lint` (backend) và `make mobile-test`, `make mobile-lint` (mobile).
- Commit đúng Conventional Commits, mỗi commit một ý nhỏ.
