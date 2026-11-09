# Đặc tả API (v1)

Tiền tố `/api/v1`. Tài liệu tương tác tại `/docs` (Swagger). Mọi endpoint (trừ `/health*`, `/auth/*`) cần header `Authorization: Bearer <access_token>`.

## Tổng quan endpoint

| Nhóm | Endpoint | Trạng thái |
|---|---|---|
| Hệ thống | `GET /health`, `GET /health/ready` (kiểm tra DB, 503 nếu lỗi) | Đã có |
| Xác thực | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh` | Đã có |
| Người dùng | `GET /users/me`, `PATCH /users/me` | Đã có |
| Cân nặng/BMI | `GET/POST /weights`, `PATCH/DELETE /weights/{id}` | Đã có |
| Nước uống | `GET/POST /water`, `PATCH/DELETE /water/{id}`, `GET /water/total` | Đã có |
| Giấc ngủ | `GET/POST /sleep`, `PATCH/DELETE /sleep/{id}` | Đã có |
| Thuốc | `GET/POST /medications`, `PATCH/DELETE /medications/{id}`, `POST/GET /medications/{id}/logs` | Đã có |
| Bước chân | `GET/POST /steps`, `PATCH/DELETE /steps/{id}` | Phase 2 |
| Bữa ăn | `GET/POST /meals`, `PATCH/DELETE /meals/{id}` | Phase 2 |
| Mục tiêu | `GET/POST /goals`, `PATCH/DELETE /goals/{id}` | Phase 2 |
| Thống kê | `GET /stats/summary`, `GET /stats/trend?metric=&range=` | Phase 4 |
| Nhắc nhở | `GET/POST /reminders`, `PATCH/DELETE /reminders/{id}` | Phase 4 |

## Quy ước chung

- JSON; thời gian theo ISO 8601, lưu và tính theo UTC.
- Lỗi luôn có dạng `{"detail": ...}`: chuỗi cho 400, 401, 403, 404, 409, 503; danh sách `{loc, msg, type}` cho lỗi kiểm tra dữ liệu 422; lỗi không lường trước trả 500 `{"detail": "Lỗi máy chủ nội bộ"}`.
- Danh sách hỗ trợ `limit` (1-200, mặc định 50), `offset`, và `from`, `to` (lọc theo thời điểm ghi), sắp xếp mới nhất trước.
- Dữ liệu thuộc về từng người dùng. Truy cập bản ghi của người khác trả `404` (không lộ sự tồn tại).
- Xóa thành công trả `204` không có nội dung; tạo mới trả `201`.

## Xác thực

| Endpoint | Body | Kết quả |
|---|---|---|
| `POST /auth/register` | `email`, `password` (8-72 ký tự), `full_name` | `201` thông tin người dùng; `409` nếu email đã tồn tại |
| `POST /auth/login` | `email`, `password` | `200` `{access_token, refresh_token, token_type}`; `401` nếu sai |
| `POST /auth/refresh` | `refresh_token` | `200` cặp token mới; `401` nếu token sai, hết hạn hoặc không phải refresh token |

Access token hết hạn sau 30 phút, refresh token sau 7 ngày (cấu hình trong `.env`). Thiếu hoặc sai access token trả `401`.

## Người dùng

- `GET /users/me`: trả `id`, `email`, `full_name`, `birth_date`, `gender`, `height_cm`, `created_at`.
- `PATCH /users/me`: cập nhật một phần `full_name`, `birth_date`, `gender` (`male`, `female`, `other`), `height_cm` (> 0, <= 300).

## Chỉ số sức khỏe

| Nhóm | Trường tạo/sửa | Trường trả thêm | Ghi chú |
|---|---|---|---|
| `/weights` | `weight_kg` (0-500], `logged_at?` | `bmi` | BMI = kg / m² làm tròn 1 chữ số, `null` nếu chưa có `height_cm`; sửa cân nặng sẽ tính lại |
| `/water` | `amount_ml` (1-5000), `logged_at?` | | `GET /water/total?date=YYYY-MM-DD` trả `{date, total_ml}` theo ngày UTC, mặc định hôm nay |
| `/sleep` | `start_at`, `end_at`, `quality?` (1-5) | `duration_minutes` | `end_at` phải sau `start_at`, nếu không trả `422` (cả khi PATCH) |

`logged_at` bỏ trống nghĩa là thời điểm hiện tại. `/sleep` lọc `from`/`to` theo `start_at`.

## Thuốc

- `POST /medications`: `name`, `dosage?`, `schedule?`; `PATCH` thêm `is_active`.
- `POST /medications/{id}/logs`: `taken_at?` (mặc định hiện tại), `taken` (mặc định `true`; `false` = bỏ lỡ liều). `GET` cùng đường dẫn trả nhật ký mới nhất trước.
- Thuốc không thuộc người dùng trả `404` cho mọi thao tác, kể cả `logs`.

## Ví dụ

```bash
curl -X POST /api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"an@example.com","password":"matkhau123"}'

curl -X POST /api/v1/weights -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"weight_kg": 70}'
# {"id":1,"weight_kg":70.0,"bmi":22.9,"logged_at":"2026-11-09T08:00:00Z"}
```

**Giới hạn tốc độ và đo thời gian:** `POST /auth/login` giới hạn theo IP (mặc định 10 lượt/60 giây, cấu hình `LOGIN_RATE_LIMIT`, `LOGIN_RATE_WINDOW_SECONDS`); vượt ngưỡng trả `429` kèm header `Retry-After`. Giới hạn lưu trong bộ nhớ nên chỉ đúng khi chạy một instance. Mọi phản hồi có header `X-Process-Time-Ms`; request chậm hơn `SLOW_REQUEST_MS` (mặc định 500) bị ghi log cảnh báo.
