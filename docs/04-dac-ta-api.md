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
| Bước chân | `GET/POST /steps`, `PATCH/DELETE /steps/{id}` | Đã có |
| Bữa ăn | `GET/POST /meals`, `PATCH/DELETE /meals/{id}`, `GET /meals/total` | Đã có |
| Mục tiêu | `GET/POST /goals`, `PATCH/DELETE /goals/{id}`; `metric`: `weight`, `water`, `sleep`, `steps`, `calories`; `period`: `daily`, `weekly`; mỗi chỉ số tối đa một mục tiêu đang hoạt động (trùng trả 409) | Đã có |
| Thống kê | `GET /stats/summary?date=` (số liệu trong ngày và tiến độ mục tiêu), `GET /stats/trend?metric=&range=` | Đã có |
| Nhắc nhở | `GET/POST /reminders`, `PATCH/DELETE /reminders/{id}`; `kind`: `water`, `medication`, `sleep`; `at_time`: giờ địa phương `HH:MM:SS`; `enabled`: bật/tắt | Đã có |

## Quy ước chung

- JSON; thời gian theo ISO 8601, lưu và tính theo UTC.
- Lỗi luôn có dạng `{"detail": ...}`: chuỗi cho 400, 401, 403, 404, 409, 503; danh sách `{loc, msg, type}` cho lỗi kiểm tra dữ liệu 422; lỗi không lường trước trả 500 `{"detail": "Lỗi máy chủ nội bộ"}`.
- Danh sách hỗ trợ `limit` (1-200, mặc định 50), `offset`, và `from`, `to` (lọc theo thời điểm ghi), sắp xếp mới nhất trước.
- Dữ liệu thuộc về từng người dùng. Truy cập bản ghi của người khác trả `404` (không lộ sự tồn tại).
- Xóa thành công trả `204` không có nội dung; tạo mới trả `201`.

### Nhắc nhở

- `GET /reminders`: danh sách của người dùng hiện tại, sắp xếp theo `at_time` tăng dần; hỗ trợ `limit` (1-200, mặc định 50) và `offset`.
- `POST /reminders`: body gồm `kind` (`water`, `medication`, `sleep`), `at_time` (giờ dạng `HH:MM:SS`) và `enabled` (mặc định `true`). Trả `201` cùng bản ghi đã tạo.
- `PATCH /reminders/{id}`: cập nhật một hoặc nhiều trường `kind`, `at_time`, `enabled`; body rỗng hoặc giá trị `null` không hợp lệ.
- `DELETE /reminders/{id}`: xóa nhắc nhở của người dùng hiện tại, trả `204`. ID không tồn tại hoặc thuộc người dùng khác trả `404`.

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
| `/steps` | `steps` (số nguyên không âm), `day` (`YYYY-MM-DD`) | | Mỗi user có một bản ghi mỗi ngày. `POST` upsert theo `(user_id, day)`: `201` khi tạo, `200` khi cập nhật bản ghi ngày đó. `GET` hỗ trợ `from`, `to` theo ngày, `limit`, `offset`; PATCH có thể đổi `steps` hoặc `day`, ngày đã tồn tại trả `409`. |
| `/meals` | `meal_type` (`breakfast`, `lunch`, `dinner`, `snack`), `name`, `calories` (số nguyên không âm), `logged_at?` | | `GET /meals/total?date=YYYY-MM-DD&tz_offset=420` trả `{date, total_calories}`; mặc định ngày hiện tại theo `tz_offset`. Tổng chỉ tính dữ liệu của user hiện tại. |

`logged_at` bỏ trống nghĩa là thời điểm hiện tại. `/sleep` lọc `from`/`to` theo `start_at`. `/steps` yêu cầu client gửi rõ `day` vì ngày ghi phụ thuộc ngày người dùng chọn. `/meals` lọc `from`/`to` theo `logged_at`; tổng calories quy đổi ranh giới ngày từ `tz_offset` sang UTC.

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

## Thống kê tổng quan

`GET /stats/summary?date=YYYY-MM-DD&tz_offset=420` (`date` mặc định là hôm nay theo múi giờ `tz_offset`) trả:

| Trường | Ý nghĩa |
|---|---|
| `weight` | Cân nặng ghi cuối trong ngày (`latest_kg`, `bmi`, `logged_at`), `null` nếu chưa ghi |
| `water_ml` | Tổng nước uống trong ngày |
| `sleep_minutes` | Tổng phút các giấc ngủ kết thúc trong ngày |
| `medications` | `taken` (đã uống) và `missed` (bỏ lỡ) trong ngày |
| `goals` | Tiến độ từng mục tiêu đang hoạt động: `current_value`, `target_value`, `percent`, `achieved`, `unit` |

Cách tính tiến độ mục tiêu: chu kỳ `daily` lấy trong ngày, `weekly` lấy 7 ngày gần nhất tính cả ngày đang xem. `water`, `steps`, `calories` cộng dồn; `sleep` lấy trung bình phút mỗi đêm có dữ liệu (mục tiêu ngủ là phút mỗi đêm); `percent` không giới hạn 100. Mục tiêu `weight` có `percent` và `achieved` là `null` vì không biết hướng tăng hay giảm, client so `current_value` với `target_value`. `steps` và `calories` đã có API ghi nhận nhưng chưa được nối vào thống kê nên `current_value` vẫn là 0.

## Xu hướng theo thời gian

`GET /stats/trend?metric=weight|water|sleep|steps|calories&range=7d|30d|90d&date=YYYY-MM-DD&tz_offset=420` trả `points` gồm đúng một điểm `{date, value}` cho mỗi ngày trong `range` kết thúc ở `date` (mặc định hôm nay, UTC), kèm `unit`, `from_date`, `to_date`. Ngày không có dữ liệu có `value` là `null` để biểu đồ phân biệt "không ghi" với "bằng 0". Cách tính giá trị theo ngày giống `summary`: `water` cộng dồn, `sleep` tổng phút theo ngày thức dậy, `weight` lấy bản ghi cuối ngày; `steps` và calories đã có API ghi nhận nhưng chưa được nối vào thống kê nên hiện trả `null`.

Truy vấn lọc theo thời gian trên các bảng log dùng chỉ mục ghép theo `user_id` và cột thời gian; `sleep_logs` có thêm chỉ mục `(user_id, end_at)` (migration `0007`), còn `step_logs` dùng unique index `(user_id, day)` (migration `0008`).

## Múi giờ của thống kê

Dữ liệu lưu theo UTC, nhưng ranh giới "ngày" của `/stats/summary` và `/stats/trend` tính theo múi giờ người dùng qua tham số `tz_offset`: số phút lệch so với UTC, từ `-720` đến `840`, mặc định `0` (UTC). Ví dụ Việt Nam là `420`: bản ghi lúc 23:30 UTC ngày 9/3 thuộc ngày 10/3, và `date` bỏ trống nghĩa là hôm nay theo giờ Việt Nam. Giá trị ngoài khoảng trả `422`. Client nên gửi offset hiện tại của thiết bị (ví dụ Dart: `DateTime.now().timeZoneOffset.inMinutes`). `/water/total` vẫn tính theo UTC.
