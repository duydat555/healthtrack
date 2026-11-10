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
| Mục tiêu | Chỉ một mục tiêu đang hoạt động cho mỗi user/chỉ số; metric, period và target ngoài giới hạn bị từ chối; lọc và phân trang hoạt động | Integration (`backend/tests/test_goals.py`) | Đã kiểm tra: 9 test pass |
| Nhật ký thuốc | Ghi nhận đã uống/bỏ lỡ, mặc định thời điểm, mới nhất trước; validate đầu vào, phân trang và không truy cập thuốc của user khác | Integration (`backend/tests/test_medications.py`) | Đã kiểm tra: 7 test pass |
| Liquid Glass | iOS 26 hiện kính native, iOS cũ hiện bản dự phòng | Thiết bị | Chưa làm |
| Widget LiquidGlass | Không có channel thì dùng BackdropFilter | Widget | Đạt |

## Mục tiêu
Độ phủ backend từ 70%; CI chạy lint, test, build trên mọi PR. Ma trận đầy đủ do Tài hoàn thiện ở issue Phase 0.

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
