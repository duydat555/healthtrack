# Kế hoạch kiểm thử

## Cấp độ
| Cấp | Công cụ | Phạm vi | Chủ trì |
|---|---|---|---|
| Unit / Widget | pytest, flutter_test | Hàm, service, widget | Từng dev |
| Integration | pytest + httpx, PostgreSQL | Endpoint với CSDL thật | Tân, Tài |
| E2E | Flutter integration_test trên iOS Simulator | Luồng đăng ký, ghi chỉ số, xem biểu đồ | Tài |
| Thiết bị | Thủ công trên Simulator iOS 26 và iOS 18 | Liquid Glass, bản dự phòng, Reduce Transparency | Tài |
| UAT | Thủ công với stakeholder | Luồng lõi theo Acceptance Criteria | Tài, Đạt |

## Ma trận kiểm thử (mẫu)
| Chức năng | Acceptance Criteria | Loại test | Trạng thái |
|---|---|---|---|
| Health check | `GET /health` trả 200 | Unit | Đạt |
| Đăng ký | Email trùng bị từ chối, mật khẩu được băm | Integration | Chưa làm |
| Ghi cân nặng | Chỉ thấy dữ liệu của chính mình | Integration | Chưa làm |
| Liquid Glass | iOS 26 hiện kính native, iOS cũ hiện bản dự phòng | Thiết bị | Chưa làm |
| Widget LiquidGlass | Không có channel thì dùng BackdropFilter | Widget | Đạt |

## Mục tiêu
Độ phủ backend từ 70%; CI chạy lint, test, build trên mọi PR. Ma trận đầy đủ do Tài hoàn thiện ở issue Phase 0.

## E2E đăng ký, đăng nhập và ghi chỉ số (Issue #60)

Bài kiểm tra `mobile/integration_test/auth_metrics_e2e_test.dart` chạy ứng dụng trên Android Emulator/thiết bị Android hoặc iOS Simulator với backend local. Bài test tạo một tài khoản giả lập có email duy nhất mỗi lần chạy, đăng xuất rồi đăng nhập lại, ghi cân nặng giả lập và xác nhận giá trị xuất hiện trên Tổng quan. Cuối bài test, token được xóa khỏi vùng lưu trữ bảo mật của thiết bị. Tài khoản và bản ghi giả lập vẫn còn trong CSDL local.

### Windows + Android Emulator, không dùng Docker

1. Trong pgAdmin, tạo database `healthtrack` với owner `postgres` nếu database chưa có.
2. Trong thư mục `backend`, nếu chưa có `.env`, chạy `Copy-Item ..\.env.example .env`. Mở `backend/.env`, thêm hoặc sửa `DATABASE_URL=postgresql+asyncpg://postgres:<mật-khẩu>@localhost:5432/healthtrack`, thay `<mật-khẩu>` bằng mật khẩu bạn đã đặt. Giữ file `.env` local, không commit.
3. Bật dịch vụ PostgreSQL, rồi ở PowerShell:

```powershell
Set-Location D:\healthtrack-git\backend
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

4. Mở Android Emulator và chạy ở PowerShell thứ hai:

```powershell
Set-Location D:\healthtrack-git\mobile
D:\flutter\bin\flutter.bat devices
D:\flutter\bin\flutter.bat test integration_test/auth_metrics_e2e_test.dart `
  -d emulator-5554 `
  --dart-define=API_URL=http://10.0.2.2:8000/api/v1
```

Thay `emulator-5554` bằng device ID Android Emulator đang chạy, lấy từ kết quả `flutter devices`. `10.0.2.2` là địa chỉ Android Emulator dùng để truy cập máy Windows. Với điện thoại Android thật, thay bằng IP LAN của máy tính và cho phép kết nối qua firewall. Không cần `make seed` vì test tự đăng ký tài khoản mới. Chỉ dùng CSDL phát triển local, không dùng tài khoản hoặc dữ liệu sức khỏe thật.

### iOS Simulator (macOS)

Khởi động backend local, mở Simulator, rồi chạy từ thư mục `mobile`:

```bash
flutter test integration_test/auth_metrics_e2e_test.dart -d SIMULATOR_ID --dart-define=API_URL=http://localhost:8000/api/v1
```

### Kết quả chạy

| Ngày chạy | Thiết bị / hệ điều hành | Backend | Kết quả | Ghi chú |
|---|---|---|---|---|
| 10/11/2026 | Pixel 4a, Android 13 (API 33), Windows 11 | Backend local, PostgreSQL | PASS — 1 integration test | `flutter test integration_test/auth_metrics_e2e_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8000/api/v1`; dùng tài khoản và cân nặng giả lập. |
## Hiệu năng giao diện (issue #66)
Bài đo tự động: `mobile/integration_test/dashboard_perf_test.dart`, chạy bằng
`cd mobile && flutter test integration_test/dashboard_perf_test.dart -d <thiết bị>`.
Bài đo cuộn màn Tổng quan lên xuống 3 lần, đếm số lần rebuild từng widget (`debugOnRebuildDirtyWidget`) và thu thời gian build/raster của từng khung hình (`FrameTiming`, cùng nguồn số liệu với DevTools).

Kết quả trên iPhone 13 Simulator (iOS 27.2), chế độ debug, 271 khung hình:

| Chỉ số | p50 | p90 | Lớn nhất | Ngân sách 60 fps |
|---|---|---|---|---|
| Build (ms) | 0,77 | 2,42 | 8,04 | 16,6 |
| Raster (ms) | 0,74 | 1,09 | 4,74 | 16,6 |

- Khi cuộn, `HomeScreen`, `_RingsCard`, `ActivityRings`, `MetricCard`, `_WeekChart` đều **rebuild 0 lần**. Chỉ có phần nội bộ của `ListView` (`KeepAlive`, `KeyedSubtree`) và vài `Text` được dựng lại. Test sẽ **thất bại** nếu một widget nặng bị rebuild, để chặn hồi quy.
- Mọi khung hình đều dưới ngân sách ở chế độ debug (chậm hơn profile/release nhiều lần), nên có dư địa.

Giới hạn cần biết:
- Simulator không hỗ trợ chế độ profile; số tuyệt đối chỉ để so sánh tương đối. Số lần rebuild không phụ thuộc chế độ. Nên đo lại trên iPhone thật ở chế độ profile trước khi nghiệm thu.
- Màn Tổng quan hiện dùng dữ liệu mẫu và chưa có provider Riverpod, nên chưa có gì để tối ưu bằng `select`. Khi nối API, dùng `ref.watch(provider.select((s) => s.field))` cho widget chỉ cần một phần trạng thái, rồi chạy lại bài đo này.
- Vòng Activity Rings và biểu đồ cột có hoạt ảnh vào màn (khoảng 1 giây); `ActivityRings` dùng `TweenAnimationBuilder`, chỉ vẽ lại chính nó.
