# Thiết kế cơ sở dữ liệu

Bản nháp ban đầu, Tân hoàn thiện và chốt ở issue Phase 1.

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
        datetime created_at
    }
    WEIGHT_LOGS { int id PK  int user_id FK  float weight_kg  datetime logged_at }
    WATER_LOGS { int id PK  int user_id FK  int amount_ml  datetime logged_at }
    SLEEP_LOGS { int id PK  int user_id FK  datetime start_at  datetime end_at  int quality }
    STEP_LOGS { int id PK  int user_id FK  int steps  date day }
    MEAL_LOGS { int id PK  int user_id FK  string meal_type  string name  int calories  datetime logged_at }
    MEDICATIONS { int id PK  int user_id FK  string name  string dosage  string schedule }
    MEDICATION_LOGS { int id PK  int medication_id FK  datetime taken_at  bool taken }
    GOALS { int id PK  int user_id FK  string metric  float target  string period }
    REMINDERS { int id PK  int user_id FK  string kind  time at_time  bool enabled }
```

Quy ước: tên bảng số nhiều, snake_case, khóa chính `id`, có `created_at`. Mọi thay đổi cấu trúc phải đi kèm migration Alembic.
