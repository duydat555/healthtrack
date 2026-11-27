# Hợp đồng dữ liệu buổi tập (Workout), Phase 8

Tài liệu chung cho các task Phase 8 (Epic #238, Change Request #237). Mọi phần (tracking, ảnh ghép, lịch sử, API, kiểm thử) đọc và ghi đúng định dạng này để làm song song mà không chờ nhau.

- Mã nguồn: `mobile/lib/features/workout/workout.dart` (model), `workout_math.dart` (phép tính), `workout_repository.dart` (lưu trữ).
- Dữ liệu mẫu: `mobile/test/fixtures/workouts/*.json`, sinh bằng `cd mobile && dart run tool/gen_workout_fixtures.dart`.
- Đổi định dạng: tăng `v`, sửa tài liệu này và báo cả nhóm trong Epic #238.

## Dữ liệu mẫu
Đây là dữ liệu **tổng hợp**: đường đi theo tuyến có thật ở Đà Nẵng, còn điểm GPS, tốc độ, độ cao và nhiễu do máy sinh (hạt giống cố định nên chạy lại cho cùng kết quả). Không phải buổi tập thật của ai.

| File | Môn | Quãng đường | Thời gian vận động | Ghi chú |
|---|---|---|---|---|
| `sample-run-han-river.json` | Chạy bộ | 5,19 km | 27:50 | Ven sông Hàn, có 1 lần dừng 30 giây (2 đoạn) |
| `sample-ride-my-khe.json` | Đạp xe | 10,06 km | 27:54 | Đường biển Võ Nguyên Giáp, đi rồi về |
| `sample-walk-vku.json` | Đi bộ | 2,20 km | 24:57 | Một vòng quanh khu VKU |

## JSON một buổi tập
```json
{
  "v": 1,
  "id": "sample-run-han-river",
  "sport": "run",
  "title": "Chạy ven sông Hàn",
  "startedAt": "2026-11-21T22:30:00.000Z",
  "endedAt": "2026-11-21T22:58:20.000Z",
  "movingSeconds": 1670.0,
  "distanceM": 5190.12,
  "elevationGainM": 12.3,
  "avgPaceSecPerKm": 321.77,
  "kcal": 337.36,
  "splits": [
    {"index": 1, "distanceM": 1000, "seconds": 322.4, "paceSecPerKm": 322.4, "elevationDeltaM": 1.8}
  ],
  "polyline": "y~w~Bwz_tS...",
  "points": [
    {"lat": 16.06071, "lon": 108.22652, "t": "2026-11-21T22:30:00.000Z", "alt": 8.1, "speed": 3.02, "acc": 6.4}
  ]
}
```
(Các số trong ví dụ là minh họa định dạng; số thật xem file mẫu.)

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `v` | số nguyên | Phiên bản định dạng, hiện là 1 |
| `id` | chuỗi | Chỉ chữ, số, `-`, `_`, tối đa 64 ký tự; app tạo bằng uuid |
| `sport` | `run` \| `walk` \| `ride` | Môn tập |
| `title` | chuỗi | Tên buổi tập, mặc định "Chạy bộ buổi sáng"… |
| `startedAt`, `endedAt` | ISO 8601 UTC | Bắt đầu và kết thúc (gồm cả lúc tạm dừng) |
| `movingSeconds` | số | Thời gian vận động, không tính lúc tạm dừng |
| `distanceM` | số | Quãng đường (m), không tính quãng giữa hai đoạn |
| `elevationGainM` | số | Độ cao leo (m), cộng theo bậc 3 m để bỏ nhiễu GPS |
| `avgPaceSecPerKm` | số hoặc null | Nhịp trung bình (giây/km); null khi chưa có quãng đường |
| `kcal` | số | Năng lượng vận động ròng (xem dưới) |
| `splits` | mảng | Mỗi km một phần tử; phần tử cuối là phần lẻ (≥ 10 m) |
| `polyline` | chuỗi | Đường đi mã hóa Google Encoded Polyline, độ chính xác 1e5 |
| `points` | mảng | Các điểm GPS đã lọc; có thể bỏ khi chỉ cần vẽ (dùng `polyline`) |

Một điểm: `lat`, `lon`, `t` (bắt buộc); `alt` (m), `speed` (m/s), `acc` (sai số ngang, m), `seg` (số đoạn, mặc định 0, tăng sau mỗi lần tạm dừng).

## Cách tính
- **Quãng đường:** cộng khoảng cách haversine giữa hai điểm liên tiếp cùng đoạn.
- **Split:** mốc km rơi giữa hai điểm thì nội suy thời gian và độ cao theo tỉ lệ quãng đường.
- **Calo (`workoutKcal`):**
  - Chạy 1,0 và đi bộ 0,5 kcal mỗi kg mỗi km (phương trình chuyển hóa ACSM).
  - Đạp xe theo MET của Compendium of Physical Activities 2011: dưới 19 km/h 6,8; 19–22 km/h 8,0; từ 22 km/h 10,0. Năng lượng ròng = (MET − 1) × kg × giờ.

## Lưu trữ
- **`WorkoutRepository`:** `list()` (mới nhất trước), `get(id)`, `save(workout)`, `delete(id)`.
- **`LocalWorkoutRepository`:** mỗi buổi là một file `<id>.json` trong thư mục `workouts/` của app. Ghi qua file tạm rồi đổi tên.
- **`ApiWorkoutRepository`** (task #251) sẽ dùng cùng interface, gọi API bên dưới.

## API dự kiến cho backend (task #247)
| Phương thức | Đường dẫn | Mô tả |
|---|---|---|
| GET | `/api/v1/workouts?limit&before` | Danh sách của người dùng hiện tại, mới nhất trước, không kèm `points` |
| GET | `/api/v1/workouts/{id}` | Một buổi, kèm `points` |
| PUT | `/api/v1/workouts/{id}` | Tạo hoặc thay thế (id do app tạo nên gửi lại không nhân đôi) |
| DELETE | `/api/v1/workouts/{id}` | Xóa |

Body PUT và kết quả GET dùng đúng JSON ở trên. Mọi truy vấn lọc theo người dùng đăng nhập; truy cập buổi tập của người khác trả 404 (rủi ro R04).
