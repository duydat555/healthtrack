# Triển khai

| Thành phần | Nơi chạy | Ghi chú |
|---|---|---|
| Backend | Render (Docker, HTTPS) | Biến môi trường `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS` |
| CSDL | Neon hoặc Supabase (PostgreSQL) | Backend tự chạy `alembic upgrade head` khi khởi động |
| App iOS | TestFlight (cần Apple Developer) hoặc cài trực tiếp qua Xcode | Build: `flutter build ipa --dart-define=API_URL=https://<backend>/api/v1` |

## Chạy app trỏ tới backend
- Local: `make mobile` (mặc định `http://localhost:$BACKEND_PORT/api/v1`; Simulator dùng chung localhost với Mac).
- Cloud: `cd mobile && flutter run --dart-define=API_URL=https://<backend>/api/v1`.

**Phương án dự phòng khi demo:** chạy `make up` + Simulator trên máy local và có video quay sẵn.

## Dữ liệu demo
`make seed` tạo tài khoản `demo@healthtrack.example` (mật khẩu `demo12345`) cùng 30 ngày dữ liệu giả lập: cân nặng, nước uống, giấc ngủ, 2 loại thuốc và nhật ký uống. Dữ liệu hoàn toàn giả, cố định (seed ngẫu nhiên) nên mỗi lần demo giống nhau. Chạy lại an toàn: chỉ xóa và tạo lại dữ liệu của tài khoản demo, không đụng người dùng khác. Script từ chối chạy khi `ENV=production` trừ khi thêm `--force`.

## Sao lưu và khôi phục CSDL
**Local (Docker):**
```bash
make backup                                   # tạo backups/healthtrack-<thời gian>.sql
# Khôi phục (ghi đè dữ liệu hiện tại):
docker compose exec -T db psql -U healthtrack healthtrack < backups/healthtrack-<thời gian>.sql
```
Thư mục `backups/` không commit vào git, vì có thể chứa dữ liệu người dùng.

**Cloud (Neon/Supabase):** dùng `pg_dump` với chuỗi kết nối (bỏ phần `+asyncpg` trong `DATABASE_URL`):
```bash
pg_dump "postgresql://<user>:<pass>@<host>/<db>" --no-owner -f healthtrack.sql
psql "postgresql://<user>:<pass>@<host>/<db>" -f healthtrack.sql   # khôi phục
```
Neon và Supabase còn có sao lưu/khôi phục theo thời điểm trong trang quản trị; nên tạo một bản sao lưu trước khi nghiệm thu (UAT) và trước mỗi lần thay đổi cấu trúc CSDL.

Cần bổ sung địa chỉ triển khai thật ở issue Phase 5.
