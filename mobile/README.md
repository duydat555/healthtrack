# HealthTrack - App iOS (Flutter)

Xem hướng dẫn cài đặt ở [README gốc](../README.md#2-app-ios-người-làm-mobile) và kiến trúc ở [docs/02](../docs/02-kien-truc-he-thong.md).

```bash
flutter pub get
flutter run --dart-define=API_URL=http://localhost:8000/api/v1
flutter test                       # unit + widget test
flutter test integration_test/dashboard_perf_test.dart -d <thiết bị>   # đo hiệu năng
# E2E thật với backend (cần make up và make seed; CẢNH BÁO: xóa token đã lưu trên thiết bị đó):
flutter test integration_test/e2e_backend_test.dart -d <thiết bị> --dart-define=API_URL=http://localhost:8200/api/v1
```

Tài khoản demo sau `make seed`: `demo@healthtrack.example` / `demo12345`.

## Kết nối backend
| Lớp | File | Việc làm |
|---|---|---|
| Token | `lib/core/token_storage.dart` | Lưu access/refresh token trong Keychain (`flutter_secure_storage`) |
| HTTP | `lib/core/api_client.dart` | `dioProvider` gắn Bearer; gặp 401 thì dùng refresh token lấy cặp mới rồi thử lại **một lần** (nhiều request cùng 401 chỉ làm mới một lần); làm mới thất bại thì xóa phiên và về màn đăng nhập |
| Đăng nhập | `lib/features/auth/` | `authProvider` (`AsyncNotifier<User?>`), màn đăng nhập, đăng ký |
| Điều hướng | `lib/app/router.dart` | `routerProvider` tự chuyển theo trạng thái đăng nhập |
| Dữ liệu | `lib/features/health/` | Repository, model, provider cho cân nặng, nước, giấc ngủ, mục tiêu, thuốc |

Lưu ý về múi giờ: backend gộp theo ngày UTC, còn app tính "hôm nay" theo giờ máy (đầu ngày địa phương), lấy danh sách bản ghi rồi cộng ở app. Danh sách giới hạn 200 bản ghi mỗi lần gọi.
Thanh tab Liquid Glass trên iOS 26 là view native nên test Flutter không "bấm" được; test điều hướng bằng router.

Liquid Glass nằm trong plugin cục bộ [packages/liquid_glass](packages/liquid_glass/).
