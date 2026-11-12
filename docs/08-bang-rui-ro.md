# Risk Register v2 — HealthTrack

**Phiên bản:** 2 — đánh giá lại sau các sự kiện thực tế
**Ngày cập nhật:** 2026-11-11
**Phạm vi:** rà soát 13 rủi ro từ v1, ghi nhận sự kiện đã xảy ra, cập nhật điểm rủi ro còn lại và bổ sung rủi ro về toolchain Android, môi trường E2E local.

v1 là bản đánh giá ban đầu. v2 ghi lại những gì đã quan sát trong issue, CI, PR và quá trình chạy thử trên máy phát triển. Sự kiện được ghi nhận không đồng nghĩa hậu quả vẫn còn; trạng thái và điểm v2 phản ánh rủi ro còn lại sau xử lý. Không có dữ liệu sức khỏe thật trong tài liệu này.

## Thang điểm và cách đọc

- **Xác suất (X), 1–5:** 1 Hiếm; 2 Ít khả năng; 3 Có thể; 4 Nhiều khả năng; 5 Gần như chắc chắn.
- **Tác động (T), 1–5:** 1 Không đáng kể; 2 Nhỏ; 3 Trung bình; 4 Lớn; 5 Rất nghiêm trọng.
- **Điểm = X × T**, từ 1 đến 25. Điểm v1 được giữ làm mốc; điểm v2 là đánh giá rủi ro còn lại tại ngày cập nhật, không phải số đo thống kê.
- **Ưu tiên:** 1–4 Thấp; 5–9 Trung bình; 10–16 Cao; 17–25 Rất cao.
- `Đã xảy ra` nghĩa là trigger đã được quan sát; việc xử lý có thể đã hoàn tất. Rủi ro còn lại vẫn được theo dõi nếu chưa loại bỏ nguyên nhân.

## Risk Register

| Mã | Rủi ro | Điểm v1 | Điểm v2 | Diễn biến / bằng chứng | Xử lý và trạng thái hiện tại | Người phụ trách |
|---|---|---:|---:|---|---|---|
| R01 | Trễ tiến độ do nhóm vừa học vừa làm, phụ thuộc issue và thời gian rảnh khác nhau. | 16 (4×4) | 16 (4×4) | Chưa có bằng chứng cụ thể về mốc P0 bị trễ trong dữ liệu rà soát. | Giữ nguyên; theo dõi blocker, mốc phụ thuộc và cập nhật Kanban. **Mở — chưa xác nhận sự cố.** | Lê Duy Đạt — PM / Scrum Master |
| R02 | Yêu cầu hoặc tiêu chí nghiệm thu chưa rõ hay thay đổi. | 12 (3×4) | 12 (3×4) | Chưa ghi nhận thay đổi yêu cầu không qua xác nhận trong bằng chứng rà soát. | Giữ nguyên; xác nhận AC và quyết định thay đổi qua Change Request. **Mở — chưa xác nhận sự cố.** | Lê Duy Đạt — PM / Scrum Master |
| R03 | Lộ dữ liệu sức khỏe hoặc thông tin xác thực qua secret, log, cấu hình cloud hay fixture thật. | 10 (2×5) | 10 (2×5) | Không phát hiện secret hoặc dữ liệu sức khỏe thật trong các diff/test đã rà soát cho v2. | Giữ nguyên; tiếp tục cấm commit `.env`, dùng dữ liệu giả và rà soát log/secret. **Mở — chưa xác nhận sự cố.** | Đặng Ngọc Tân — Backend Engineer |
| R04 | API trả/sửa dữ liệu người dùng khác do thiếu lọc quyền sở hữu (IDOR). | 15 (3×5) | 15 (3×5) | Chưa có test ownership thất bại hoặc truy cập chéo được xác nhận trong bằng chứng v2. | Giữ nguyên; test hai tài khoản cho CRUD và review owner scope. **Mở — chưa xác nhận sự cố.** | Đặng Ngọc Tân — Backend Engineer |
| R05 | Migration/schema lệch giữa local, CI và PostgreSQL, gây lỗi khởi động hoặc triển khai. | 12 (3×4) | 12 (3×4) | Máy phát triển đã chạy migration PostgreSQL local; chưa ghi nhận migration hỏng trong log được cung cấp. | Giữ nguyên; tiếp tục kiểm tra Alembic trên DB rỗng và schema nâng cấp trong CI. **Mở — chưa xác nhận sự cố.** | Đặng Ngọc Tân — Backend Engineer |
| R06 | Hợp đồng API giữa FastAPI và Flutter không khớp hoặc tích hợp muộn. | 12 (3×4) | 16 (4×4) | #69 phụ thuộc API #68; tại thời điểm rà soát, hai nhánh vẫn riêng và `origin/main` chưa chứa API nhắc nhở. Test repository #69 dùng fake API theo schema nhánh #68, chưa phải kiểm thử tích hợp backend thật. | Tăng X do phụ thuộc liên nhánh còn chờ tích hợp. Ghép OpenAPI/schema trước khi merge; sau khi #68 vào main, chạy test với backend thật. **Đang mở — chưa xác minh tích hợp thật.** | Đặng Ngọc Tân — Backend; Huỳnh Thanh Thuận — Mobile |
| R07 | Thông báo local không chạy đúng lịch do quyền, đồng bộ hoặc múi giờ. | 12 (3×4) | 12 (3×4) | Build Android đã thành công; chưa có bằng chứng kiểm tra thông báo thực tế khi app đóng, đổi múi giờ hoặc người dùng từ chối quyền. | Giữ nguyên; kiểm tra trên thiết bị Android/iOS, bao gồm quyền bị từ chối, sửa/tắt/xóa reminder và khởi động lại máy. **Mở — kiểm tra thiết bị còn thiếu.** | Nguyễn Văn Tài — QA & module nhắc nhở |
| R08 | Backend/DB cloud miễn phí ngủ đông, vượt hạn mức hoặc mất kết nối khi demo/UAT. | 12 (3×4) | 12 (3×4) | Chưa ghi nhận sự cố cloud trong bằng chứng v2. | Giữ nguyên; theo dõi health/ready, hạn mức và giữ phương án chạy local. **Mở — chưa xác nhận sự cố.** | Lê Duy Đạt — PM / Scrum Master, Tech Lead |
| R09 | Build/test iOS bị chặn bởi macOS/Xcode hoặc khác biệt phiên bản iOS. | 16 (4×4) | 16 (4×4) | Chưa có log build iOS hoặc kiểm tra trên Simulator iOS trong bằng chứng v2; việc chạy Android không xác nhận nhánh iOS. | Giữ nguyên; cần Mac/Xcode kiểm tra iOS 18 và iOS 26 trước nghiệm thu. **Mở — chưa có bằng chứng iOS.** | Lê Duy Đạt — Tech Lead, Swift / iOS |
| R10 | Test không đủ sâu/độ phủ, bỏ sót lỗi trước nghiệm thu. | 15 (3×5) | 12 (3×4) | Golden CI từng thất bại do ảnh Linux khác golden; E2E #60 từng thất bại vì tìm `Text` trong nội dung `RichText`. Các lần chạy sau pass; golden test đã ghi nhận thêm lỗi giao diện để tạo issue #145. | Giảm T vì kiểm thử đã phát hiện lỗi trước merge; tiếp tục kiểm soát golden trên đúng runner CI, chạy test liên quan và theo dõi coverage/UAT. **Đã xảy ra — đã xử lý các lỗi test, còn theo dõi.** | Nguyễn Văn Tài — QA & Test Engineer |
| R11 | Xung đột merge, chậm review hoặc tích hợp muộn do phát triển song song/phụ thuộc nhánh. | 9 (3×3) | 12 (4×3) | Merge #60 gặp conflict ở `docs/09-ke-hoach-kiem-thu.md`; conflict được giải quyết. PR #146 bị chặn chờ reviewer có quyền write. Nhóm thống nhất thành viên push nhánh và leader tổng hợp/merge cuối ngày. | Tăng X do conflict và review gate đã xảy ra; quy trình merge cuối ngày là biện pháp giảm tồn đọng. Theo dõi nhánh phụ thuộc #68/#69 và trạng thái review. **Đã xảy ra — conflict đã xử lý; chờ tích hợp/review theo quy trình.** | Lê Duy Đạt — PM / Scrum Master, Tech Lead |
| R12 | Khác biệt giao diện/hiệu năng giữa thiết bị hoặc platform làm vỡ layout. | 6 (2×3) | 12 (4×3) | Golden nhỏ trên CI lệch 0,69% (2.100 pixel); issue #145 ghi nhận `SectionHeader('Chỉ số hôm nay')` overflow ngang 4,5 px ở rộng 375 px. | Tăng X do lỗi giao diện đã xuất hiện trên màn nhỏ. Golden được cập nhật theo Linux; issue #145 vẫn cần theo dõi đến khi có bằng chứng sửa và test xác nhận. **Đã xảy ra — lỗi overflow được chuyển thành issue #145, chưa xác nhận đã đóng.** | Lê Duy Đạt — Tech Lead, Swift / iOS |
| R13 | Phát hành TestFlight chậm vì thiếu quyền Apple Developer, certificate hoặc provisioning. | 9 (3×3) | 9 (3×3) | Chưa có bằng chứng TestFlight/provisioning bị lỗi trong dữ liệu v2. | Giữ nguyên; xác nhận quyền ký sớm, chuẩn bị demo Simulator làm phương án dự phòng. **Mở — chưa xác nhận sự cố.** | Lê Duy Đạt — Tech Lead, Swift / iOS |
| R14 | Android toolchain/plugin không tương thích SDK, AGP, Gradle hoặc desugaring làm dừng build. | Chưa có trong v1 | 16 (4×4) | #60: Dart SDK ban đầu thấp hơn ràng buộc dự án; `flutter_local_notifications` yêu cầu Android API 37 trong khi app compile API 36; sau khi hạ plugin, build báo thiếu core library desugaring. | Đã nâng Flutter/Dart, cài API 37, cập nhật compileSdk/AGP và bật desugaring; APK debug build được. Ghim tương thích plugin/toolchain và giữ Android build CI. **Đã xảy ra — build hiện pass, rủi ro tái phát còn cao.** | Huỳnh Thanh Thuận — Mobile Engineer (Flutter) |
| R15 | Chuẩn bị môi trường E2E local trên Windows mất thời gian do thiếu PostgreSQL/Docker/WSL hoặc kết nối emulator tới host. | Chưa có trong v1 | 12 (4×3) | Khi bắt đầu #60, máy chưa có PostgreSQL/Docker; WSL không có distro. E2E chỉ chạy sau khi cài PostgreSQL local, tạo DB, migrate, chạy Uvicorn và dùng `10.0.2.2` từ Android Emulator. | Ghi checklist setup Windows/PostgreSQL/Flutter emulator, kiểm tra health endpoint trước E2E và ghi rõ URL theo thiết bị. **Đã xảy ra — máy hiện tại đã chạy được; thời gian setup cho thành viên khác vẫn là rủi ro.** | Nguyễn Văn Tài — QA & Test Engineer |

## Nhật ký sự kiện thực tế

| Mã | Sự kiện và bằng chứng | Rủi ro liên quan | Cách xử lý / trạng thái |
|---|---|---|---|
| E01 | Mobile CI golden test thất bại: `foundation_widgets_small.png` lệch 0,69%, 2.100 pixel; workflow được chỉnh để golden sinh trên Ubuntu giống CI và cập nhật ảnh. | R10, R12 | CI mobile sau đó pass; giữ golden do runner Linux sinh làm baseline. |
| E02 | Issue #145 ghi nhận SectionHeader tràn 4,5 px ở màn 375 px sau kiểm tra widget/golden. | R12 | Đã có issue theo dõi; chưa kết luận đã sửa nếu chưa có test/screenshot xác nhận. |
| E03 | #60 build Android vướng Dart SDK, Android API 37 và core library desugaring sau thay đổi plugin thông báo. | R14 | Cập nhật Flutter/Dart, Android SDK, Gradle/AGP, compileSdk và desugaring; APK debug build pass. |
| E04 | E2E #60 không tìm thấy chuỗi `72,4` bằng `find.text` dù UI hiển thị `72,4 kg` trong RichText. | R10 | Đổi assertion sang `find.text('72,4 kg', findRichText: true)`; integration test sau đó pass. |
| E05 | E2E local ban đầu bị chặn bởi thiếu PostgreSQL/Docker/WSL; cấu hình Android Emulator cần gọi host qua `10.0.2.2`. | R15 | Cài PostgreSQL local, tạo `healthtrack`, chạy Alembic/Uvicorn và chạy test trên emulator. |
| E06 | Merge #60 có conflict tài liệu; PR #146 yêu cầu review của reviewer có write access. | R11 | Conflict được giải quyết và push; nhóm thống nhất leader tổng hợp/merge nhánh cuối ngày. |

## Theo dõi phiên bản và nguồn

- **v1:** đánh giá ban đầu, lưu tại [08-risk-register-v1.xlsx](08-risk-register-v1.xlsx).
- **v2:** đánh giá lại ngày 2026-11-11; bảng Excel đầy đủ gồm điểm trước/sau, sự kiện, cách xử lý và thang điểm: [04_Risk_Register_Evolution.xlsx](04_Risk_Register_Evolution.xlsx).
- Nguồn sự kiện: lịch sử issue #54, #60, #145; CI run 129627800631; PR #146; log chạy E2E do thành viên cung cấp; trạng thái nhánh/merge tại thời điểm cập nhật.
- Điểm v2 là đánh giá còn lại của nhóm sau xử lý, không thay thế xác nhận cuối cùng của owner. Cập nhật lại khi issue #145 được đóng, API #68 tích hợp, notification được kiểm tra trên thiết bị và CI/PR thay đổi trạng thái.
