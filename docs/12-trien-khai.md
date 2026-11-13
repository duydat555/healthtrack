# Triển khai

| Thành phần | Nơi chạy | Ghi chú |
|---|---|---|
| Backend | Render (Docker, HTTPS) | Biến môi trường `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS` |
| CSDL | Neon hoặc Supabase (PostgreSQL) | Backend tự chạy `alembic upgrade head` khi khởi động |
| App iOS | TestFlight (cần Apple Developer) hoặc cài trực tiếp qua Xcode | Build: `flutter build ipa --dart-define=API_URL=https://<backend>/api/v1` |

## Triển khai từng bước (khoảng 10 phút, cần tài khoản của bạn)
Đã chuẩn bị sẵn: `render.yaml` (Render Blueprint), backend tự chuẩn hóa chuỗi kết nối Neon, kiểm tra cấu hình production khi khởi động, workflow deploy. Việc còn lại cần đăng nhập bằng tài khoản thật:

1. **Neon (CSDL):** vào neon.tech, đăng nhập bằng GitHub, tạo project (vùng Singapore cho gần Việt Nam). Mở *Connection Details*, bấm sao chép chuỗi kết nối `postgresql://...`. Dán nguyên dạng, không cần sửa: backend tự đổi sang `postgresql+asyncpg://` và đổi `sslmode` thành `ssl`.
2. **Render (backend):** vào render.com, đăng nhập bằng GitHub. Chọn *New > Blueprint*, chọn repo `duydat555/healthtrack`, bấm *Apply*. Khi Render hỏi `DATABASE_URL`, dán chuỗi từ Neon. `JWT_SECRET` do Render tự sinh. Đợi build xong (vài phút).
3. **Kiểm tra:** mở `https://<tên-service>.onrender.com/api/v1/health/ready`, thấy `{"status":"ready","database":"ok"}` là xong. Nếu địa chỉ khác `healthtrack-api.onrender.com`, sửa biến `CORS_ORIGINS` trên Render cho khớp.
4. **Bật deploy tự động:** trong service trên Render, *Settings > Deploy Hook*, sao chép URL. Trên GitHub repo, *Settings > Secrets and variables > Actions*: tạo secret `RENDER_DEPLOY_HOOK_URL` (dán URL hook) và variable `BACKEND_URL` (địa chỉ gốc của backend). Từ đó mỗi lần code `backend/**` vào `main`, workflow `Deploy Backend` tự deploy và chờ `/health/ready`.
5. **Nạp dữ liệu demo (không bắt buộc):** trên máy bạn, `cd backend && DATABASE_URL='<chuỗi Neon>' ENV=development python -m app.seed`. Tài khoản `demo@healthtrack.example` / `demo12345`.
6. **Trỏ app tới cloud:** `cd mobile && flutter run --dart-define=API_URL=https://<tên-service>.onrender.com/api/v1`.

Lưu ý về gói miễn phí: Render ngủ sau khoảng 15 phút không có request, request đầu tiên mất 30 đến 60 giây để thức dậy; Neon cũng tự tạm dừng khi rảnh. Trước buổi demo hãy mở `/health/ready` một lần để làm nóng.

Đã kiểm tra cục bộ: chạy backend với `ENV=production`, chuỗi kết nối dạng Neon và secret ngẫu nhiên thì migration chạy đến `0009` và `/health/ready` trả `ready`; secret mặc định bị từ chối khởi động. Chưa kiểm tra được trên Render và Neon thật vì chưa có tài khoản.

## Cấu hình bắt buộc khi triển khai (#79)
Backend tự từ chối khởi động ở `ENV=production` nếu cấu hình yếu (xem checklist trong docs/02):

| Biến | Giá trị trên Render | Vì sao |
|---|---|---|
| `ENV` | `production` | bật kiểm tra bảo mật khi khởi động |
| `JWT_SECRET` | chuỗi ngẫu nhiên từ 32 ký tự (`openssl rand -hex 32`) | production từ chối secret mặc định hoặc ngắn |
| `DATABASE_URL` | chuỗi kết nối Neon, dạng `postgresql+asyncpg://...` (thêm `?ssl=require` nếu nhà cung cấp yêu cầu) | |
| `CORS_ORIGINS` | danh sách origin thật, không dùng `*` | production cấm `*` |
| `FORWARDED_ALLOW_IPS` | `*` | **bắt buộc** để uvicorn đọc IP thật của người dùng từ header `X-Forwarded-For` |

Về `FORWARDED_ALLOW_IPS`: giới hạn đăng nhập (`/auth/login`, 10 lượt mỗi phút) đếm theo địa chỉ IP. Sau proxy của Render, nếu không đặt biến này thì mọi người dùng cùng một IP của proxy và **bị giới hạn chung**, tức 10 lần đăng nhập mỗi phút cho cả hệ thống. Chỉ đặt `*` khi backend chỉ nhận request qua proxy của nền tảng, vì nếu mở thẳng ra Internet thì header này có thể bị giả mạo.

Rate limit lưu trong bộ nhớ nên chỉ đúng với một instance; chạy nhiều instance thì cần chuyển sang Redis.

Kiểm tra sống và sẵn sàng: `GET /api/v1/health` (tiến trình còn chạy) và `GET /api/v1/health/ready` (kết nối được CSDL, 503 nếu lỗi). Dùng `health/ready` làm Health Check Path của Render.

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

## Địa chỉ đang chạy
| Thành phần | Nơi chạy |
|---|---|
| Backend (HTTPS) | https://healthtrack-api-w0sm.onrender.com (Swagger: `/docs`, sống: `/api/v1/health`, sẵn sàng: `/api/v1/health/ready`) |
| CSDL | Neon PostgreSQL, vùng Singapore, database `healthtrack_db` (qua pooler) |

Đã kiểm tra trên cloud (10/11/2026): `/health/ready` trả `ready`; đăng ký, đăng nhập, ghi nước và `/stats/summary` chạy qua HTTPS; CORS từ chối origin lạ; migration chạy đến `0009`. Chạy app tới cloud: `cd mobile && flutter run --dart-define=API_URL=https://healthtrack-api-w0sm.onrender.com/api/v1`.

### Lỗi đã gặp khi triển khai lần đầu
- **Dán chuỗi Neon bị xuống dòng thành dấu cách**: `...ap-southeast 1.aws...` thay vì `ap-southeast-1`. Backend báo `socket.gaierror: Name or service not known`, Render báo "Port scan timeout" và deploy `update_failed`. Khi dán `DATABASE_URL`, kiểm tra chuỗi nằm trên một dòng, không có dấu cách.
- **Địa chỉ Render có hậu tố ngẫu nhiên** (`-w0sm`), nên `CORS_ORIGINS` đặt theo `healthtrack-api.onrender.com` là sai. Dùng địa chỉ thật hiển thị trên Render.
- **Deploy Hook không lấy được qua API Render**, phải sao chép từ *Settings > Deploy Hook* trong giao diện.

## AI Coach (Claude)
Thêm biến môi trường `ANTHROPIC_API_KEY` trên Render (mục Environment) để bật `/api/v1/coach`. Để trống thì Coach trả 503 và phần còn lại của API chạy bình thường. Model mặc định: chat `claude-haiku-5-5`, nhận xét tuần `claude-sonnet-5-5` (đổi bằng `COACH_CHAT_MODEL`, `COACH_WEEKLY_MODEL`). Mỗi người dùng tối đa 20 lượt gọi Coach mỗi phút (`COACH_RATE_LIMIT`).

## Widget và Live Activity (iOS)
- Target `HealthTrackWidget` (WidgetKit, iOS 17+) nằm trong `mobile/ios/HealthTrackWidget/`: widget nhỏ, vừa, widget Lock Screen và Live Activity uống nước (Dynamic Island).
- App ghi số liệu cho widget qua App Group `group.vn.edu.vku.healthtrack` (UserDefaults), cầu nối Dart tại `mobile/lib/features/widget/` và Swift tại `ios/Runner/WidgetBridge.swift`. Live Activity cập nhật cục bộ, không cần máy chủ push.
- Chạy được trên Simulator. Lên máy thật cần tài khoản Apple Developer đăng ký App Group `group.vn.edu.vku.healthtrack` cho cả hai bundle id (`vn.edu.vku.healthtrack` và `vn.edu.vku.healthtrack.HealthTrackWidget`), xem task #80.
- Thêm widget: nhấn giữ màn hình chính, bấm +, chọn HealthTrack.
## AI local trên Mac (MLX)
Chế độ riêng tư chạy model trên chính Mac Apple Silicon của bạn, dữ liệu sức khỏe không đi ra ngoài.
1. `make llm` tự cài `mlx-lm` vào `~/.cache/healthtrack-llm/venv`, tải model rồi mở server tại `http://127.0.0.1:8090/v1` (API giống OpenAI). Lần đầu tải vài GB. `make llm-stop` để tắt, `make llm-bench` để đo tốc độ.
2. Model mặc định `mlx-community/Qwen3.5-9B-MLX-4bit`; đổi bằng `LLM_MODEL=... make llm`.
3. Backend chạy trong Docker trên cùng Mac: đặt `LOCAL_LLM_URL=http://host.docker.internal:8090/v1` trong `.env` rồi `make up`.
4. Backend trên Render không với tới Mac trong mạng nhà. Muốn dùng từ xa, mở Tailscale hoặc Cloudflare Tunnel từ Mac, đặt `LOCAL_LLM_URL` trỏ tới đó và đặt `LOCAL_LLM_API_KEY` để bảo vệ.
5. `GET /coach/providers` cho biết nguồn nào đang dùng được; `POST /coach/chat` nhận `provider` là `auto` (ưu tiên local, mất kết nối thì dùng Claude), `local` hoặc `claude`.

Model local chỉ trả lời dựa trên số liệu được tóm tắt sẵn trong lời nhắc; ghi chỉ số bằng câu tự nhiên cần Claude (tool use).

### Kết quả đo AI local (Mac mini M6, 32 GB RAM, 13/11/2026)
Đo bằng `make llm-bench` với một câu hỏi tiếng Việt, tắt chế độ suy nghĩ.

| Model | Thời gian tới token đầu | Tốc độ sinh | RAM tiến trình |
|---|---|---|---|
| `mlx-community/Qwen3.5-9B-MLX-4bit` | 0,23 giây | khoảng 25 token/giây | khoảng 4 GB |

Chọn Qwen3.5 9B 4-bit làm mặc định: trả lời tiếng Việt tự nhiên, đủ nhanh để hiện từng chữ và còn dư RAM. Đã thử đầu cuối: app gọi backend (Docker), backend đọc số liệu của người dùng demo và gọi server MLX, câu trả lời dựa đúng trên số liệu đó. Lần đầu bật server mất thêm vài phút để tải khoảng 5,9 GB.

## Dùng Coach từ iPhone qua Tailscale

Mac mini chạy backend (`make up`) và AI local (`make llm`); iPhone nối vào qua Tailscale nên không cần mở cổng ra Internet.

1. Cài Tailscale trên Mac mini và iPhone, đăng nhập cùng một tài khoản. Lấy IP của Mac mini bằng `tailscale ip -4` (ví dụ `100.88.248.82`).
2. Chạy app trỏ vào Mac mini: `flutter run --dart-define=API_URL=http://100.88.248.82:8200/api/v1` (cổng là `BACKEND_PORT` trong `.env`).
3. Không cần `ANTHROPIC_API_KEY`: Coach tự chọn AI local khi server MLX đang chạy (`provider=auto`).
4. Muốn HTTPS có chứng chỉ hợp lệ: bật Serve một lần tại https://login.tailscale.com/f/serve rồi chạy `tailscale serve --bg --https=443 http://localhost:8200`. Khi đó `API_URL=https://<tên-máy>.<tailnet>.ts.net/api/v1`.

Nếu Coach báo lỗi: kiểm tra `make llm` đang chạy (`scripts/local-llm.sh status`) và `GET /api/v1/coach/providers` trả `local: true`.
