# AGENTS.md - Hướng dẫn cho AI agent làm việc trong HealthTrack

Tài liệu này dành cho mọi AI coding agent (Claude Code, Codex, Cursor, Copilot...). Viết bằng tiếng Việt, hãy trả lời và viết tài liệu bằng tiếng Việt.

## Tổng quan
HealthTrack là app theo dõi sức khỏe cá nhân. Đây là đồ án môn Quản trị dự án phần mềm, nên **lịch sử commit, issue và PR là bằng chứng chấm điểm**.

## Cấu trúc
- `backend/`: FastAPI. `app/api/v1/` (router), `app/models/` (SQLAlchemy), `app/schemas/` (Pydantic), `app/services/` (nghiệp vụ), `app/crud/` (truy vấn), `app/core/` (config, db, security). Migration trong `alembic/versions/`.
- `mobile/`: app Flutter, giao diện chính chạy trên iOS.
  - `lib/core/` (theme, api_client), `lib/app/` (router), `lib/widgets/` (widget dùng chung), `lib/features/<tính-năng>/` (màn hình, provider, repository theo từng tính năng).
  - `packages/liquid_glass/`: plugin Flutter cục bộ cho Liquid Glass. Dart ở `lib/liquid_glass.dart`, Swift ở `ios/liquid_glass/Sources/liquid_glass/`. Plugin tự đăng ký, không sửa `AppDelegate.swift`.
- `docs/`: tài liệu dự án. Khi đổi kiến trúc, CSDL hoặc API thì cập nhật file tương ứng.

## Lệnh
```bash
make up / make down        # chạy / dừng backend bằng Docker
make test / make lint      # pytest / ruff cho backend
make migrate m="mô tả"     # tạo và áp dụng migration Alembic
make mobile                # chạy app Flutter trên iOS Simulator
make mobile-test           # flutter test
make mobile-lint           # flutter analyze
```

## Quy ước
- **Git:** nhánh `feat|fix|docs|test|chore/<số-issue>-<mô-tả>`; commit theo Conventional Commits; không push thẳng vào `main`; mọi thay đổi qua PR có `Closes #<số-issue>`.
- **Python:** type hint đầy đủ, async/await, ruff (line 100). Logic nghiệp vụ đặt ở `services/`, router chỉ nhận/trả dữ liệu. Mọi bảng mới phải có migration Alembic.
- **Dart/Flutter:** theo `flutter_lints`, cấu trúc feature-first, state bằng Riverpod, điều hướng bằng go_router, gọi API qua `ApiClient` (Dio). Màu và chữ lấy từ `lib/core/theme.dart`, không hard-code.
- **Liquid Glass:** chỉ dùng widget `LiquidGlass` (`import 'package:liquid_glass/liquid_glass.dart';`). Widget này tự chọn bản Swift native trên iOS 26+ hoặc bản dự phòng `BackdropFilter`. Không đặt quá nhiều platform view trong danh sách cuộn dài (tốn hiệu năng).
- **Swift:** code native đặt trong `mobile/packages/liquid_glass/ios/liquid_glass/Sources/liquid_glass/` (không thêm file .swift vào `ios/Runner`, vì phải sửa tay `project.pbxproj`), bọc API mới bằng `if #available(iOS 26.0, *)` và luôn có nhánh dự phòng.
- **Màn hình:** kiểm tra trên iPhone nhỏ (SE) và lớn (Pro Max), chế độ sáng/tối.
- **Test:** tính năng mới đi kèm test (pytest ở `backend/tests/`, `flutter test` ở `mobile/test/` và `mobile/packages/liquid_glass/test/`, E2E ở `mobile/integration_test/`).
- **Bí mật:** không commit `.env`. Biến mới thêm vào `.env.example`.

## Cách nhận việc
1. Đọc issue được giao (Acceptance Criteria và Definition of Done trong `docs/10-definition-of-done.md`).
2. Chỉ làm đúng phạm vi issue. Việc ngoài phạm vi thì tạo issue mới hoặc Change Request, không tự mở rộng (kiểm soát scope creep).
3. Mỗi issue làm trên một nhánh riêng, commit nhỏ, mở PR khi xong.
4. **Không commit thay người khác.** Mỗi thành viên phải tự có commit của mình trong phần việc mình được giao.

## Không làm
- Không dump nhiều thay đổi không liên quan vào một commit.
- Không sửa `main` trực tiếp, không bỏ qua CI.
- Không đưa dữ liệu sức khỏe thật vào repo hoặc test.
