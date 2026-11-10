# Kế hoạch kiểm thử và ma trận kiểm thử

Tài liệu này liên kết phạm vi sản phẩm trong Project Charter/WBS, Acceptance Criteria (AC) từ tài liệu đặc tả hoặc issue, và loại kiểm thử dự kiến. Ma trận là kế hoạch bao phủ, không phải báo cáo hoàn tất kiểm thử.

## Cấp độ kiểm thử

| Cấp độ | Công cụ / cách thực hiện | Phạm vi | Chủ trì theo kế hoạch |
|---|---|---|---|
| Unit | pytest, flutter_test | Hàm, service, validation và widget độc lập | Dev phụ trách; QA rà soát |
| Integration | pytest + httpx + PostgreSQL | API, xác thực, truy vấn và migration với CSDL | Backend, QA |
| Widget | flutter_test | Hiển thị, tương tác, loading/error/empty và accessibility cơ bản | Mobile, QA |
| E2E | Flutter integration_test trên iOS Simulator / backend triển khai | Luồng người dùng xuyên app và API | QA, Mobile |
| Bảo mật | Kiểm tra tự động và checklist OWASP | IDOR, xác thực, injection, rate limit, dữ liệu nhạy cảm | QA, Backend |
| Thiết bị | Thủ công trên Simulator iOS 26 và iOS 18; iPhone thật khi cần | Liquid Glass, dự phòng, kích thước, sáng/tối, Reduce Transparency | QA, Mobile, iOS |
| UAT | Kịch bản theo AC với stakeholder | Luồng cốt lõi, phản hồi và xác nhận nghiệm thu | QA, PM |

## Ma trận chức năng

**Cách đọc trạng thái:** “Có test trong repo” chỉ xác nhận đã tìm thấy test source, không khẳng định test đã chạy hoặc pass. “Đã ghi nhận” chỉ áp dụng cho kết quả cụ thể có trong tài liệu. Các mục còn lại là kế hoạch chưa có bằng chứng kết quả trong lần cập nhật này. Không dùng dữ liệu sức khỏe thật.

| Mã / chức năng | Acceptance Criteria (AC) có căn cứ | Loại kiểm thử | Nguồn AC | Trạng thái / bằng chứng hiện có |
|---|---|---|---|---|
| ENV-01 Khởi động backend và health | `docker compose up` chạy DB, backend, Adminer; `GET /api/v1/health` trả `ok` | Integration, E2E | T11, API spec | Có `backend/tests/test_health.py`; chưa chạy trong Issue #22 |
| ENV-02 Sẵn sàng và lỗi API | `/health/ready` kiểm tra DB; lỗi có dạng `{detail}` nhất quán | Integration | T14, API spec | Có `backend/tests/test_errors_and_ready.py`; chưa chạy trong Issue #22 |
| CI-01 Kiểm tra pull request | Backend CI chạy ruff + pytest; mobile CI chạy analyze + test và build iOS Simulator trên macOS | Integration (CI) | T12, DoD | Có cấu hình CI trong repo; chưa xác minh lần chạy CI cho nhánh này |
| AUTH-01 Đăng ký | `POST /auth/register` trả 201; email trùng trả 409; mật khẩu lưu dạng băm | Integration, bảo mật | T18, API spec | Có `backend/tests/test_auth_register.py`; chưa chạy trong Issue #22 |
| AUTH-02 Đăng nhập và refresh | Đăng nhập trả access/refresh token; refresh cấp token mới; thông tin đăng nhập sai trả 401 | Integration, bảo mật | T19, API spec | Có `backend/tests/test_auth_login.py`; chưa chạy trong Issue #22 |
| USER-01 Hồ sơ của tôi | `GET /users/me` cần token; `PATCH /users/me` cập nhật trường hồ sơ được hỗ trợ | Integration, bảo mật | T20, API spec | Có `backend/tests/test_users_me.py`; chưa chạy trong Issue #22 |
| AUTH-03 Truy cập chưa xác thực | Endpoint cần JWT từ chối request thiếu/sai access token với 401 | Integration, bảo mật | API spec, T61 | Có `backend/tests/test_security.py`; chưa chạy trong Issue #22 |
| DATA-01 Cô lập dữ liệu theo user | Người dùng chỉ đọc/sửa/xóa bản ghi của mình; truy cập ID của user khác trả 404 | Integration, bảo mật | API spec, T61; WBS 3.2–3.4 | Có test ownership ở các suite API hiện hữu; chưa chạy trong Issue #22 |
| WEIGHT-01 Cân nặng và BMI | CRUD chỉ trên dữ liệu của user; BMI tính từ chiều cao hồ sơ; lọc `from/to`, phân trang | Unit, integration, bảo mật | T24, API spec | Có `backend/tests/test_weights.py`; chưa chạy trong Issue #22 |
| WATER-01 Nhật ký nước | CRUD `/water`; tổng theo ngày trả đúng; API spec quy định lượng 1–5000 ml và hợp đồng phân trang/lọc chung | Unit, integration | T25, API spec | Có `backend/tests/test_water.py`; chưa chạy trong Issue #22 |
| SLEEP-01 Nhật ký giấc ngủ | CRUD `/sleep`; tính thời lượng; từ chối `end_at` trước `start_at` | Unit, integration | T26, API spec | Có `backend/tests/test_sleep.py`; chưa chạy trong Issue #22 |
| STEPS-01 Bước chân | CRUD `/steps`, mỗi ngày một bản ghi (upsert); chi tiết giới hạn/validation: **Cần xác nhận** | Unit, integration, bảo mật | T27, WBS 3.2, API spec (Phase 2) | Kế hoạch; API spec ghi Phase 2, chưa có test source theo tên chức năng trong repo |
| MEALS-01 Bữa ăn | CRUD `/meals` với loại bữa sáng/trưa/tối/phụ; tổng calories theo ngày; chi tiết giới hạn/validation: **Cần xác nhận** | Unit, integration, bảo mật | T28, WBS 3.2, API spec (Phase 2) | Kế hoạch; API spec ghi Phase 2, chưa có test source theo tên chức năng trong repo |
| GOAL-01 Mục tiêu sức khỏe | Hỗ trợ metric/period đã liệt kê; mỗi metric tối đa một mục tiêu active, mục tiêu trùng trả 409 | Unit, integration | T31, API spec | Có `backend/tests/test_goals.py`; chưa chạy trong Issue #22 |
| MED-01 Thuốc | Tạo/sửa/xóa thuốc; chỉ user sở hữu truy cập được; trường bắt buộc/tuỳ chọn theo API spec | Unit, integration, bảo mật | T32, API spec | Có `backend/tests/test_medications.py`; chưa chạy trong Issue #22 |
| MED-02 Nhật ký uống thuốc | Ghi `taken_at` và `taken`; mặc định thời điểm hiện tại và `taken=true`; danh sách mới nhất trước | Unit, integration | T33, API spec | Có `backend/tests/test_medications.py`; chưa chạy trong Issue #22 |
| STATS-01 Tổng quan ngày | Summary tính cân nặng cuối ngày, tổng nước, phút ngủ, log thuốc và tiến độ mục tiêu theo định nghĩa API | Unit, integration | T46, API spec | Có `backend/tests/test_stats_summary.py`; chưa chạy trong Issue #22 |
| STATS-02 Xu hướng | Range 7/30/90 ngày có điểm mỗi ngày; ngày thiếu dữ liệu là null; phép tổng hợp theo metric khớp API spec | Unit, integration | T47, API spec | Có `backend/tests/test_stats_trend.py`; chưa chạy trong Issue #22 |
| STATS-03 Múi giờ | `tz_offset` trong -720..840; ngày summary/trend theo offset; ngoài khoảng trả 422 | Unit, integration | API spec; WBS 3.4 | Có `backend/tests/test_stats_tz_offset.py`; chưa chạy trong Issue #22 |
| REM-01 API nhắc nhở | CRUD `/reminders`; mỗi nhắc nhở có loại, giờ và trạng thái bật/tắt | Unit, integration, bảo mật | T53, Issue #68 (nội dung người giao cung cấp), API spec | Trên `origin/main` tại thời điểm lập ma trận, API spec ghi Phase 4; kiểm thử theo kế hoạch, cần đồng bộ khi API được tích hợp |
| REM-02 Thông báo cục bộ | Lập lịch thông báo đúng giờ; xin quyền iOS; đồng bộ lịch khi reminder thay đổi; có unit test bộ lập lịch | Unit, integration, E2E | T54 | Kế hoạch; chưa có bằng chứng test trong repo tại baseline ma trận |
| REM-03 Màn hình nhắc nhở | Danh sách và form chọn giờ kiểu iOS; bật/tắt từng nhắc nhở; kết nối API thật | Widget, E2E, UAT | T55 | Kế hoạch; màn hình/module chưa có trong mã mobile tại baseline ma trận |
| MOB-01 Đăng nhập và ghi dữ liệu | App có đăng ký/đăng nhập; các form ghi chỉ số kết nối API thật | Widget, integration, E2E | E6; T42–T45; WBS 4.3 | Có test widget/auth và `mobile/integration_test/app_test.dart`, `e2e_backend_test.dart`; chưa chạy trong Issue #22 |
| MOB-02 Dashboard | Thẻ tóm tắt nước, ngủ, bước, calories, cân nặng; kéo để làm mới; loading và empty state | Widget, E2E | T49 | Có widget/integration test liên quan dashboard; AC chưa được xác minh đầy đủ bằng một kết quả test trong lượt này |
| MOB-03 Biểu đồ xu hướng | Hiển thị biểu đồ theo metric; chọn 7/30/90 ngày; chạm xem giá trị | Widget, E2E | T50, T52 | Có `mobile/integration_test/app_test.dart`; chưa chạy trong Issue #22 |
| UI-01 Điều hướng và trạng thái giao diện | Điều hướng tab; màn hình có loading/error/empty; Semantics cho VoiceOver và tương phản theo AC T63 | Widget, thiết bị | T10, T63, WBS 4.1 | Có test widget trong `mobile/test/`; chưa chạy trong Issue #22 |
| IOS-01 Liquid Glass và dự phòng | iOS 26 dùng native glass; iOS 18 có BackdropFilter; kiểm tra Reduce Transparency; đo FPS khi cuộn | Widget, thiết bị, hiệu năng | T76–T80, WBS 4.2 | Có test package Liquid Glass; kiểm tra thiết bị và kết quả FPS còn là kế hoạch; chưa chạy trong Issue #22 |
| SEC-01 Kiểm thử bảo mật cơ bản | Checklist kiểm tra IDOR, SQL injection, XSS và rate limit; ghi nhận phát hiện thành issue | Bảo mật, integration | T61 | Có `backend/tests/test_security.py` và `test_rate_limit_timing.py`; checklist OWASP toàn diện chưa có kết quả ghi nhận ở đây |
| PERF-01 Hiệu năng dashboard | Đo frame build/raster và rebuild widget; kiểm tra lại trên iPhone thật ở profile trước nghiệm thu | Hiệu năng, thiết bị | T51, Issue #66, WBS 5.1 | Đã ghi nhận trong phần “Hiệu năng giao diện” bên dưới cho iPhone 13 Simulator debug; chưa có đo profile trên iPhone thật |
| CLOUD-01 Triển khai backend | Backend HTTPS; migration tự chạy khi khởi động; biến môi trường an toàn | Integration, bảo mật, E2E | T64, WBS 2.0 | Kế hoạch; chưa ghi nhận kết quả triển khai trong ma trận này |
| CLOUD-02 Phát hành và giám sát | Workflow deploy sau merge main; endpoint sống để giám sát; app TestFlight/Xcode gọi API cloud HTTPS | Integration, E2E | T65–T66 | Kế hoạch; chưa ghi nhận kết quả phát hành trong ma trận này |
| UAT-01 Nghiệm thu luồng lõi | Kịch bản dựa trên AC; ít nhất 10 người dùng thử; ghi phản hồi và lỗi | UAT | T68, Charter, WBS 6.1 | Kế hoạch; chưa có biên bản UAT được dẫn trong tài liệu này |

## Quy tắc dùng ma trận

- Trước khi kiểm thử, chọn dữ liệu giả lập; không dùng tài khoản hoặc dữ liệu sức khỏe thật.
- Với mỗi lần chạy, ghi phiên bản/commit, môi trường, lệnh hoặc kịch bản, kết quả và liên kết log/ảnh trong issue hoặc PR. Chỉ chuyển trạng thái thành đạt khi có bằng chứng kiểm tra tương ứng.
- Khi AC ở issue/WBS chưa cụ thể hoặc tài liệu mâu thuẫn, giữ trạng thái **Cần xác nhận** và làm rõ với người phụ trách; không suy diễn thành tiêu chí đạt.
- Test liên quan đến dữ liệu người dùng phải có trường hợp hai user để xác nhận quyền sở hữu và chống IDOR.

## Mục tiêu chất lượng

- Charter đặt mục tiêu coverage backend từ 70%; T59 yêu cầu báo cáo coverage trong CI và bổ sung test nhánh lỗi. Chưa xem đây là kết quả đạt nếu không có báo cáo CI/coverage kèm theo.
- T12 yêu cầu CI chạy lint/test/build theo nền tảng trên mỗi PR. Definition of Done yêu cầu CI xanh và có test cho phần mới.
- WBS 5.1 yêu cầu các luồng E2E cốt lõi và kiểm thử bảo mật; WBS 6.1 yêu cầu UAT với stakeholder. Đây là mục tiêu/kế hoạch cho đến khi có bằng chứng thực thi.

## Hiệu năng giao diện (ghi nhận từ Issue #66)

> Bài đo tự động: `mobile/integration_test/dashboard_perf_test.dart`, chạy bằng
> `cd mobile && flutter test integration_test/dashboard_perf_test.dart -d <thiết bị>`.
> Bài đo cuộn màn Tổng quan lên xuống 3 lần, đếm số lần rebuild từng widget (`debugOnRebuildDirtyWidget`) và thu thời gian build/raster của từng khung hình (`FrameTiming`, cùng nguồn số liệu với DevTools).

Kết quả đã ghi trong tài liệu cho iPhone 13 Simulator (iOS 27.2), chế độ debug, 271 khung hình:

| Chỉ số | p50 | p90 | Lớn nhất | Ngân sách 60 fps |
|---|---:|---:|---:|---:|
| Build (ms) | 0,77 | 2,42 | 8,04 | 16,6 |
| Raster (ms) | 0,74 | 1,09 | 4,74 | 16,6 |

- Ghi nhận cũ: `HomeScreen`, `_RingsCard`, `ActivityRings`, `MetricCard`, `_WeekChart` không rebuild trong lần đo nêu trên. Đây chỉ là kết quả của lần đo/môi trường đó, không phải xác nhận hiệu năng hiện tại trên mọi thiết bị.
- Simulator không cung cấp số đo profile đại diện cho thiết bị thật; cần đo lại trên iPhone thật ở chế độ profile trước nghiệm thu. Dashboard tại lần ghi nhận dùng dữ liệu mẫu, chưa có provider Riverpod.

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
