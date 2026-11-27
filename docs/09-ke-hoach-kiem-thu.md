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
| GOAL-01 Mục tiêu sức khỏe | Hỗ trợ metric/period đã liệt kê; mỗi metric tối đa một mục tiêu active, mục tiêu trùng trả 409 | Unit, integration | T31, API spec | Có `backend/tests/test_goals.py`; chưa chạy trong Issue #22 Issue #48: bổ sung test ràng buộc mục tiêu (`test_goals.py`, 9 test pass). |
| MED-01 Thuốc | Tạo/sửa/xóa thuốc; chỉ user sở hữu truy cập được; trường bắt buộc/tuỳ chọn theo API spec | Unit, integration, bảo mật | T32, API spec | Có `backend/tests/test_medications.py`; chưa chạy trong Issue #22 Issue #48: bổ sung test thuốc (`test_medications.py`, 7 test pass). |
| MED-02 Nhật ký uống thuốc | Ghi `taken_at` và `taken`; mặc định thời điểm hiện tại và `taken=true`; danh sách mới nhất trước | Unit, integration | T33, API spec | Có `backend/tests/test_medications.py`; chưa chạy trong Issue #22 Issue #48: bổ sung test nhật ký uống thuốc (`test_medications.py`). |
| STATS-01 Tổng quan ngày | Summary tính cân nặng cuối ngày, tổng nước, phút ngủ, log thuốc và tiến độ mục tiêu theo định nghĩa API | Unit, integration | T46, API spec | Có `backend/tests/test_stats_summary.py`; chưa chạy trong Issue #22 |
| STATS-02 Xu hướng | Range 7/30/90 ngày có điểm mỗi ngày; ngày thiếu dữ liệu là null; phép tổng hợp theo metric khớp API spec | Unit, integration | T47, API spec | Có `backend/tests/test_stats_trend.py`; chưa chạy trong Issue #22 |
| STATS-03 Múi giờ | `tz_offset` trong -720..840; ngày summary/trend theo offset; ngoài khoảng trả 422 | Unit, integration | API spec; WBS 3.4 | Có `backend/tests/test_stats_tz_offset.py`; chưa chạy trong Issue #22 |
| REM-01 API nhắc nhở | CRUD `/reminders`; hỗ trợ `water`, `medication`, `sleep`, `meal`, `running`, giờ trong ngày, bật/tắt; phân trang và cô lập dữ liệu theo user | Unit, integration, bảo mật | Issue #68, #250, API spec | `backend/tests/test_reminders.py` có CRUD, validation, phân trang, IDOR và tạo nhắc `running`; cần chạy test cho nhánh #250 |
| REM-02 Thông báo cục bộ | Lập lịch lặp hằng ngày theo giờ địa phương; xin quyền iOS/Android; đồng bộ lịch khi tải danh sách hoặc reminder thay đổi, bật/tắt/xóa; gồm loại chạy bộ | Unit, integration, E2E | Issue #69, #250, T54; hợp đồng API #68 | Có scheduler/repository test; thêm widget test tạo nhắc chạy bộ và xác nhận lịch được đồng bộ; cần chạy test và xác nhận trên thiết bị |
| REM-03 Màn hình nhắc nhở | Danh sách và form chọn giờ kiểu iOS; bật/tắt từng nhắc nhở; tạo nhắc chạy bộ qua API và lập lịch local | Widget, E2E, UAT | T55, Issue #250 | Màn hình đã có; test widget kiểm tra payload `running` và lịch thông báo; chưa kiểm tra notification trên thiết bị ở nhánh này |
| BADGE-01 Huy hiệu vận động | Huy hiệu buổi tập đầu tiên; một lần chạy đạt 5 km/10 km; tổng chạy 20 km từ thứ Hai đến Chủ nhật theo giờ địa phương | Unit, widget | Issue #250, hợp đồng workout #239 | `mobile/test/workout_badges_test.dart` bao phủ tập rỗng, đi bộ, mốc cự ly, cộng tuần và biên tuần; cần chạy test cho nhánh #250. Huy hiệu tính từ workout đang lưu cục bộ đến khi API #247 được tích hợp; backend gamification hiện không lưu các huy hiệu workout này. |
| MOB-01 Đăng nhập và ghi dữ liệu | App có đăng ký/đăng nhập; các form ghi chỉ số kết nối API thật | Widget, integration, E2E | E6; T42–T45; WBS 4.3 | Có test widget/auth và `mobile/integration_test/app_test.dart`, `e2e_backend_test.dart`; chưa chạy trong Issue #22 |
| MOB-02 Dashboard | Dashboard hiển thị sau đăng ký với dữ liệu lấy từ API | Widget, E2E | T49, Issue #67 | Widget test và E2E Android pass; chi tiết môi trường bên dưới |
| MOB-03 Biểu đồ xu hướng | Biểu đồ nước 7 ngày hiển thị trung bình đúng; ngày thiếu dữ liệu được tính là 0 ở dashboard | Widget, E2E | T50, T52, Issue #67 | Widget test và E2E pass với 7 ngày giả lập, gồm ngày không có dữ liệu; chi tiết bên dưới |
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

## Dashboard và biểu đồ (Issue #67)

Widget test `mobile/test/dashboard_test.dart` cấp dữ liệu trend giả gồm 7 ngày, trong đó một ngày không có dữ liệu. Test xác nhận API được gọi với metric `water` và range `7d`, ngày thiếu dữ liệu được biểu diễn là 0, và trung bình 2.500 ml trong 7 ngày được hiển thị là `0,4 lít/ngày`.

E2E `mobile/integration_test/dashboard_e2e_test.dart` đăng ký tài khoản giả mới, ghi sáu ngày dữ liệu nước giả qua API, rồi xác nhận Dashboard hiển thị điểm thiếu và trung bình biểu đồ `0,4 lít/ngày`. Tài khoản và log giả được giữ trong CSDL local; test đăng xuất để xóa token khỏi thiết bị. Chỉ chạy trên CSDL development.

Chạy widget test bằng `cd mobile && flutter test test/dashboard_test.dart`. E2E trên Android Emulator cần backend local đang chạy, rồi chạy `flutter test integration_test/dashboard_e2e_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8000/api/v1`. E2E trên iOS Simulator dùng `API_URL=http://localhost:8000/api/v1`.

Kết quả kiểm tra Issue #67:

- `flutter test test/dashboard_test.dart`: PASS — 1 test.
- `flutter analyze`: PASS — không có issue.
- `flutter test integration_test/dashboard_e2e_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8000/api/v1`: PASS — 1 E2E trên Pixel 4a, Android 13 (API 33), Windows 11, backend PostgreSQL local. Test đăng ký tài khoản mới, ghi sáu log nước giả, xác nhận dữ liệu từng ngày và trung bình biểu đồ `0,4 lít/ngày`, rồi đăng xuất. Tài khoản và log giả vẫn còn trong CSDL development local.
- Để build Android với compile SDK của Flutter hiện tại, dependency `flutter_local_notifications` được ghim ở `21.0.0`; Gradle bật core library desugaring và multidex.

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

## Coverage backend và integration test trên Simulator (issue #31, #74)

### Báo cáo coverage backend trong CI

Workflow `.github/workflows/backend-ci.yml` cài backend cùng nhóm dependency `dev` (trong đó có `pytest-cov`), chạy Ruff và pytest với coverage cho package `app`. Issue #74 đặt ngưỡng tổng tối thiểu 70%; CI in báo cáo dạng bảng vào log và GitHub Actions job summary, cột `Missing` liệt kê dòng chưa được thực thi:

```bash
cd backend
pip install -e ".[dev]"
pytest -q --cov=app --cov-report=term-missing --cov-fail-under=70
```

CI fail nếu coverage tổng package `app` thấp hơn 70%. Ba service weight, water và sleep tiếp tục có ngưỡng riêng 80%. Kết quả đạt phải được xác nhận trên lần chạy CI của PR; lịch sử báo cáo cũ ở Issue #31 không thay thế kết quả hiện tại.

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

## Cập nhật ảnh golden (widget test)
Ảnh trong `mobile/test/goldens/` phải sinh trên **Linux** (cùng môi trường với CI). Sinh trên macOS sẽ lệch khoảng 1% điểm ảnh nên CI báo đỏ, và chạy `flutter test` trên máy Mac cũng sẽ báo lệch với ảnh đã commit. Khi giao diện đổi và cần cập nhật ảnh: chạy `flutter test --update-goldens test/foundation_widgets_test.dart` trong Docker/WSL (Linux), hoặc cho một workflow tạm chạy lệnh đó trên `ubuntu-latest` rồi tải ảnh về.

## Kế hoạch kiểm thử tracking và GPX giả lập (Issue #249)

### Tài nguyên mô phỏng

File `mobile/integration_test/fixtures/tracking_route.gpx` là tuyến giả lập, không chứa dữ liệu vị trí người dùng. GPX có 14 waypoint được đánh dấu để dễ đối chiếu:

- `RUN-01`–`RUN-06` và `RUN-07`–`RUN-10`: hai chặng chạy đều, các điểm cách nhau khoảng 10–12 m.
- `STOP-01`–`STOP-03`: cùng tọa độ trong 90 giây để kiểm tra dừng.
- `NOISE-01`: một điểm lệch vài trăm mét; waypoint kế tiếp quay lại tuyến.

Tệp dùng GPX 1.1 với `<wpt>` để phát lại vị trí trên Xcode Simulator. Xcode có thể phát lại hành trình từ GPX, cập nhật vị trí, độ cao và vận tốc mô phỏng ([Apple: Simulating location in tests](https://developer.apple.com/documentation/xcode/simulating-location-in-tests)). Để cấu hình, mở `mobile/ios/Runner.xcworkspace` trong Xcode, chọn scheme `Runner` → `Edit Scheme` → `Run` → `Options` → `Core Location`, thêm GPX vào workspace rồi chọn `tracking_route.gpx`. Chạy app trên iOS Simulator và bắt đầu workout. Với test plan, chọn GPX tại `Test Plan` → `Configuration` → `Localization` → `Simulated Location`.

### Kịch bản kiểm thử thủ công

| Mã | Kịch bản | Thao tác | Kết quả cần ghi nhận |
|---|---|---|---|
| TRK-01 | Chạy đều | Phát GPX qua các waypoint `RUN-*` | Các điểm được nhận theo thứ tự; quãng đường, thời lượng và đường vẽ không lỗi. Ghi số liệu thực tế; không đặt ngưỡng sai số khi tracking chưa có tiêu chí riêng. |
| TRK-02 | Dừng giữa buổi | Phát tuyến qua `STOP-*` (90 giây cùng vị trí) | Không cộng quãng đường đáng kể trong lúc đứng yên; xác nhận `movingSeconds`/`distanceM` theo hợp đồng Workout. Nếu app đánh dấu pause thành segment mới, phép tính không cộng thời gian/quãng đường băng qua segment. |
| TRK-03 | GPS nhiễu | Phát `NOISE-01`, rồi tiếp tục đến `RUN-07` | App không crash/treo; ghi lại việc điểm nhiễu có bị loại khỏi points/polyline/distance hay không. Đối chiếu kết quả với chính sách lọc nhiễu do task tracking quy định, không suy diễn ngưỡng lọc từ GPX. |
| TRK-04 | Chạy nền | Bắt đầu workout, đưa app về nền khi GPX đang phát, rồi mở lại | Ghi trạng thái phiên, thời gian và điểm nhận trong nền; so sánh trước/sau khi mở app và đối chiếu yêu cầu nền của Workout. |
| TRK-05 | Khóa màn hình | Bắt đầu workout, khóa Simulator trong lúc phát tuyến, mở khóa và quay lại app | Ghi trạng thái workout, thời gian và điểm trước/sau khóa; kiểm tra phiên không mất hoặc bị nhân đôi. |
| TRK-06 | Từ chối quyền vị trí | Trong Settings của Simulator, đặt Location của app thành `Never`; mở app và thử bắt đầu workout | App giải thích quyền cần thiết, không crash và không lưu tuyến như có GPS. Ghi thông báo, trạng thái workout và cách khôi phục quyền. |
| TRK-07 | Mất rồi có lại GPS | Đang tracking, chọn vị trí mô phỏng `None` tại `Features` → `Location`; sau đó chọn lại GPX | Ghi nhận trạng thái mất/có lại vị trí; không vẽ đoạn giả khi không có vị trí; sau khi bật lại, tracking tiếp tục hoặc báo lỗi theo hợp đồng. |

### Ghi bằng chứng và giới hạn

Trước mỗi lượt, tạo workout mới hoặc xóa dữ liệu thử cũ. Ghi model Simulator, iOS/Xcode, commit, quyền vị trí, mã kịch bản, kết quả thực tế, ảnh/log và lỗi. Lặp mỗi kịch bản ít nhất hai lần để xem có tái lập được không. GPX chỉ cấp vị trí giả lập; các thao tác quyền, chạy nền, khóa màn hình và mất vị trí cần thực hiện riêng, GPX không mô phỏng chúng.

Repo hiện có model/phép tính Workout theo `docs/14-hop-dong-du-lieu-workout.md`, nhưng chưa có luồng UI/native GPS tracking để thực thi E2E các kịch bản này. Do đó GPX và test plan đã sẵn sàng; chưa ghi nhận kịch bản chạy đạt. Khi task triển khai tracking hoàn tất, chạy các mã TRK và cập nhật bằng chứng thực tế trước khi nghiệm thu.

