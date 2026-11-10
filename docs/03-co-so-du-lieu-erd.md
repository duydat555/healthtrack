# Thiết kế cơ sở dữ liệu

ERD ban đầu cho PostgreSQL, hoàn thiện ở issue #24. Tech Lead review và chốt trong PR.

```mermaid
erDiagram
    USERS ||--o{ WEIGHT_LOGS : ghi
    USERS ||--o{ WATER_LOGS : ghi
    USERS ||--o{ SLEEP_LOGS : ghi
    USERS ||--o{ STEP_LOGS : ghi
    USERS ||--o{ MEAL_LOGS : ghi
    USERS ||--o{ MEDICATIONS : co
    MEDICATIONS ||--o{ MEDICATION_LOGS : uong
    USERS ||--o{ GOALS : dat
    USERS ||--o{ REMINDERS : cai
    USERS {
        int id PK
        string email UK
        string password_hash
        string full_name
        date birth_date
        string gender
        float height_cm
        bool is_active
        datetime created_at
        datetime updated_at
    }
    WEIGHT_LOGS { int id PK  int user_id FK  float weight_kg  float bmi  datetime logged_at  datetime created_at }
    WATER_LOGS { int id PK  int user_id FK  int amount_ml  datetime logged_at  datetime created_at }
    SLEEP_LOGS { int id PK  int user_id FK  datetime start_at  datetime end_at  int quality  datetime created_at }
    STEP_LOGS { int id PK  int user_id FK  int steps  date day  datetime created_at }
    MEAL_LOGS { int id PK  int user_id FK  string meal_type  string name  int calories  datetime logged_at  datetime created_at }
    MEDICATIONS { int id PK  int user_id FK  string name  string dosage  string schedule  bool is_active  datetime created_at }
    MEDICATION_LOGS { int id PK  int medication_id FK  datetime taken_at  bool taken  datetime created_at }
    GOALS { int id PK  int user_id FK  string metric  float target  string period  datetime created_at }
    REMINDERS { int id PK  int user_id FK  string kind  time at_time  bool enabled  datetime created_at }
```

## Mô tả bảng

| Bảng | Mục đích | Ghi chú |
|---|---|---|
| `users` | Tài khoản và hồ sơ | `email` duy nhất; `password_hash` băm bcrypt, không lưu mật khẩu thô |
| `weight_logs` | Nhật ký cân nặng | `bmi` tính từ `weight_kg` và `users.height_cm` khi ghi |
| `water_logs` | Lượng nước uống mỗi lần | `amount_ml` > 0 |
| `sleep_logs` | Giấc ngủ | `end_at` > `start_at`; `quality` từ 1 đến 5 |
| `step_logs` | Số bước chân theo ngày | duy nhất theo (`user_id`, `day`) |
| `meal_logs` | Bữa ăn | `meal_type`: `breakfast`, `lunch`, `dinner`, `snack` |
| `medications` | Thuốc đang dùng | `schedule` mô tả lịch uống |
| `medication_logs` | Nhật ký uống thuốc | liên kết `medications`, xóa thuốc thì xóa nhật ký |
| `goals` | Mục tiêu theo chỉ số | `metric`: `weight`, `water`, `sleep`, `steps`, `calories`; `period`: `daily`, `weekly` |
| `reminders` | Nhắc nhở | `kind`: `water`, `medication`, `sleep`, `meal`... |

## Trạng thái triển khai (khớp migration thực tế)

| Bảng | Migration | Model |
|---|---|---|
| `users` | `0001` | `app/models/user.py` |
| `weight_logs` | `0002` | `app/models/weight_log.py` |
| `water_logs` | `0003` | `app/models/water_log.py` |
| `sleep_logs` | `0004` | `app/models/sleep_log.py` |
| `medications`, `medication_logs` | `0005` | `app/models/medication.py` |
| `goals` | `0006` | `app/models/goal.py`; chỉ mục unique một phần `(user_id, metric) WHERE is_active` đảm bảo mỗi chỉ số một mục tiêu đang hoạt động |
| `step_logs` | `0008` | `app/models/step_log.py`; unique index `(user_id, day)` |
| `meal_logs` | `0009` | `app/models/meal_log.py`; chỉ mục `(user_id, logged_at)` |
| `reminders` | Chưa có | Sẽ bổ sung ở issue tiếp theo |

Chi tiết đã chốt khi triển khai:

- `weight_logs.bmi` tính khi ghi từ `users.height_cm`; để `NULL` nếu hồ sơ chưa có chiều cao.
- `sleep_logs.quality` cho phép `NULL`; thời lượng không lưu mà tính từ `end_at - start_at`.
- `medication_logs` không có `user_id`; quyền sở hữu kiểm tra qua `medications.user_id`.
- Chỉ mục: `ix_weight_logs_user_id_logged_at`, `ix_water_logs_user_id_logged_at`, `ix_sleep_logs_user_id_start_at`, `ix_medications_user_id`, `ix_medication_logs_medication_id_taken_at`, `ix_users_email` (duy nhất).

## Ràng buộc và chỉ mục

- Mọi bảng dữ liệu của người dùng có `user_id` FK tới `users.id`, `ON DELETE CASCADE`. `medication_logs` có FK tới `medications.id`, cũng `ON DELETE CASCADE`.
- Mọi truy vấn lọc theo `user_id` để người dùng chỉ thấy dữ liệu của mình (xem `CRUDBase`).
- Chỉ mục: `users(email)` duy nhất; các bảng log có chỉ mục ghép (`user_id`, `logged_at`) hoặc (`user_id`, `day`) vì truy vấn thường lọc theo người dùng và khoảng thời gian.
- Thời gian lưu dạng UTC (`timestamptz`).

## Quy ước

Tên bảng số nhiều, snake_case, khóa chính `id` kiểu số nguyên tự tăng, có `created_at`. Mọi thay đổi cấu trúc phải đi kèm migration Alembic.

## Chỉ mục và hiệu năng truy vấn (issue #63)

### Chỉ mục hiện có
Mọi truy vấn của API đều lọc theo `user_id` trước, rồi theo thời gian, nên mỗi bảng nhật ký có một chỉ mục kép `(user_id, <cột thời gian>)`. Tất cả tạo qua migration.

| Bảng | Chỉ mục | Migration | Phục vụ |
|---|---|---|---|
| `users` | `ix_users_email` (unique) | `0001` | đăng nhập, kiểm tra trùng email |
| `weight_logs` | `ix_weight_logs_user_id_logged_at` | `0002` | danh sách theo khoảng ngày, xu hướng cân nặng |
| `water_logs` | `ix_water_logs_user_id_logged_at` | `0003` | danh sách, tổng nước theo ngày |
| `sleep_logs` | `ix_sleep_logs_user_id_start_at` | `0004` | danh sách theo giờ đi ngủ |
| `sleep_logs` | `ix_sleep_logs_user_id_end_at` | `0007` | thống kê theo ngày thức dậy (`/stats/*`) |
| `step_logs` | `uq_step_logs_user_day` (unique) | `0008` | upsert một bản ghi mỗi user/ngày và lọc theo ngày |
| `meal_logs` | `ix_meal_logs_user_id_logged_at` | `0009` | liệt kê và tính tổng calories theo ngày của user |
| `medications` | `ix_medications_user_id` | `0005` | danh sách thuốc của người dùng |
| `medication_logs` | `ix_medication_logs_medication_id_taken_at` | `0005` | nhật ký uống thuốc |
| `goals` | `uq_goals_user_metric_active` (unique một phần, `WHERE is_active`) | `0006` | mỗi chỉ số một mục tiêu đang hoạt động |

Các truy vấn `ORDER BY logged_at DESC, id DESC LIMIT n` dùng `Incremental Sort` trên chính chỉ mục này, nên chưa cần thêm cột `id` vào chỉ mục.

### So sánh trước và sau
PostgreSQL 16, 250 người dùng, 500.000 dòng `water_logs` và 500.000 dòng `weight_logs` trải trong 2 năm. Thời gian thực thi trung vị của 7 lần chạy `EXPLAIN ANALYZE`, đo cho một người dùng.

| Truy vấn | Không có chỉ mục | Có chỉ mục | Nhanh hơn | Kiểu quét sau khi có chỉ mục |
|---|---|---|---|---|
| Q1: danh sách 30 ngày gần nhất, 50 dòng (nước) | 6,379 ms | 0,020 ms | khoảng 320 lần | Index Scan + Incremental Sort |
| Q2: tổng nước trong 1 ngày | 6,404 ms | 0,009 ms | khoảng 710 lần | Index Scan |
| Q3: xu hướng cân nặng theo ngày, 90 ngày | 6,714 ms | 0,077 ms | khoảng 87 lần | Index Scan + Aggregate |

Nếu không có chỉ mục, PostgreSQL quét toàn bảng (`Seq Scan`) và thời gian tăng theo tổng số dòng của mọi người dùng; có chỉ mục thì chỉ đọc phần dữ liệu của chính người dùng đó.

Lưu ý khi đọc số liệu: đo trên máy cá nhân với dữ liệu đã nằm trong bộ nhớ đệm, nên con số tuyệt đối chỉ để so sánh tương đối. Chưa có API thống kê thật (#61, #62), ba truy vấn trên mô phỏng đúng dạng truy vấn mà các endpoint đó sẽ dùng; nên chạy lại script sau khi các endpoint hoàn thành.

Tái lập: tạo CSDL thử, chạy `alembic upgrade head`, rồi chạy `scripts/bench_indexes.sql` (cách chạy ghi ở đầu file).
