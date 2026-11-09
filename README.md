# HealthTrack

Ứng dụng theo dõi sức khỏe cá nhân: ghi cân nặng/BMI, nước uống, giấc ngủ, bước chân, bữa ăn, thuốc; xem biểu đồ; đặt mục tiêu; nhận nhắc nhở.

Đồ án môn **Quản trị dự án phần mềm** (VKU, Khoa Khoa học Máy tính, GV: TS. Nguyễn Thanh Tuấn). Nguồn đề tài: Pathway 3, bài toán vận hành thực tế tại VKU (stakeholder là một CLB sinh viên).

## Nhóm thực hiện

| Thành viên | GitHub | Vai trò |
|---|---|---|
| Lê Duy Đạt | [@duydat555](https://github.com/duydat555) | PM / Scrum Master + Tech Lead (kiêm Swift / iOS) |
| Đặng Ngọc Tân | [@ngoctan2503](https://github.com/ngoctan2503) | Backend Engineer |
| Huỳnh Thanh Thuận | [@phonEIT](https://github.com/phonEIT) | Mobile Engineer (Flutter) |
| Nguyễn Văn Tài | [@nguyenvantai12](https://github.com/nguyenvantai12) | QA & Test Engineer (kiêm module nhắc nhở) |

## Công nghệ

- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2 (async), Alembic, PostgreSQL 16, JWT
- **App iOS (giao diện chính):** Flutter (Dart) với Riverpod, go_router, Dio, fl_chart
- **Liquid Glass:** Swift/SwiftUI `.glassEffect()` (iOS 26+), nhúng vào Flutter qua platform view; iOS cũ và Android tự dùng bản dự phòng
- **Hạ tầng:** Docker Compose (backend), GitHub Actions, Render (backend), TestFlight (app)

## Chạy nhanh (5 phút)

### 1. Backend (mọi thành viên)
Chỉ cần [Docker Desktop](https://www.docker.com/products/docker-desktop/) và `git`.

```bash
git clone https://github.com/duydat555/healthtrack.git
cd healthtrack
make setup     # tạo .env và build image
make up        # chạy db, backend, adminer
```

| Dịch vụ | Địa chỉ |
|---|---|
| API + Swagger | http://localhost:8000/docs |
| Adminer (xem CSDL) | http://localhost:8080 (hệ thống: PostgreSQL, máy chủ: `db`, user/mật khẩu/CSDL: `healthtrack`) |

Nếu cổng bị trùng với dự án khác, đổi `BACKEND_PORT`, `DB_PORT`, `ADMINER_PORT` trong `.env` rồi `make up` lại.

Lệnh hay dùng: `make test`, `make lint`, `make migrate m="mô tả"`, `make logs`, `make down`.

### 2. App iOS (người làm mobile)
Cần máy Mac có Xcode (kèm iOS Simulator), Flutter và CocoaPods (một số package pub.dev vẫn cần):

```bash
brew install --cask flutter
brew install cocoapods
# Cài Xcode từ App Store, rồi:
sudo xcode-select -s /Applications/Xcode.app && xcodebuild -runFirstLaunch
flutter doctor         # kiểm tra môi trường

make up                # backend phải chạy trước
make mobile-setup      # flutter pub get (plugin dùng Swift Package Manager)
make mobile            # mở Simulator và chạy app
make mobile-dev        # như trên, và TỰ hot reload khi lưu file Dart (đổi máy: make mobile-dev DEVICE="iPhone 16 Pro")
```

Không có Mac thì vẫn viết UI Flutter được trên Android emulator; khi đó Liquid Glass tự dùng bản dự phòng (`BackdropFilter`).

## Cấu trúc thư mục

```
backend/    API FastAPI (app/, tests/, alembic/)
mobile/     App Flutter (lib/ là Dart; packages/liquid_glass/ là plugin Swift Liquid Glass)
docs/       Tài liệu dự án và kiến trúc (xem docs/00-muc-luc.md)
scripts/    Script tạo labels, milestones, issues trên GitHub
.github/    CI, mẫu issue, mẫu pull request
```

## Quy trình làm việc

1. Vào tab **Issues**, nhận issue có label `owner:<tên bạn>` của phase hiện tại.
2. Tạo nhánh `feat/<số-issue>-<mô-tả-ngắn>` từ `main`.
3. Commit theo [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`), commit nhỏ và thường xuyên.
4. Mở Pull Request, ghi `Closes #<số-issue>`, chờ ít nhất 1 người duyệt và CI xanh.

Chi tiết xem [CONTRIBUTING.md](CONTRIBUTING.md) và [docs/11-quy-trinh-git.md](docs/11-quy-trinh-git.md).

## Tài liệu

Mục lục đầy đủ tại [docs/00-muc-luc.md](docs/00-muc-luc.md). Quy tắc cho AI agent: [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md).
