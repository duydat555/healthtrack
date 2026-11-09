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

## Coverage backend và integration test trên Simulator (issue #31)

### Báo cáo coverage backend trong CI

Workflow `.github/workflows/backend-ci.yml` cài backend cùng nhóm dependency `dev` (trong đó có `pytest-cov`), chạy Ruff và pytest với coverage cho package `app`. Báo cáo dạng bảng được in trong log của bước pytest trên GitHub Actions; cột `Missing` liệt kê dòng chưa được thực thi:

```bash
cd backend
pip install -e ".[dev]"
pytest -q --cov=app --cov-report=term-missing
```

Kết quả của từng lần chạy phải được xem tại log CI tương ứng. Việc cấu hình xuất báo cáo không tự chứng minh coverage đạt mục tiêu 70% của Charter; không đặt ngưỡng fail mới trong Issue #31.

### Chạy integration test mẫu trên iOS Simulator

Test mẫu `mobile/integration_test/app_test.dart` mở ứng dụng và xác nhận màn Tổng quan hiển thị. Cần máy Mac có Xcode và iOS Simulator đã khởi động. Từ thư mục repo:

```bash
cd mobile
flutter pub get
flutter devices
flutter test integration_test/app_test.dart -d <device-id>
```

Thay `<device-id>` bằng ID Simulator iOS trong kết quả `flutter devices`. Test đạt khi lệnh kết thúc thành công và assertion tìm thấy nội dung `Hôm nay`. Nếu cần xem danh sách Simulator cài trong Xcode, chạy `xcrun simctl list devices available` trên macOS.

Mobile CI hiện chạy format, analyze và unit/widget test trên Ubuntu; bước integration test trên iOS Simulator được thực hiện riêng theo lệnh trên, không được tính là đã chạy chỉ vì CI unit test xanh. Ghi lại model Simulator, phiên bản iOS, commit và kết quả chạy trong PR/issue.

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
