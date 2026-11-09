# HealthTrack - App iOS (Flutter)

Xem hướng dẫn cài đặt ở [README gốc](../README.md#2-app-ios-người-làm-mobile) và kiến trúc ở [docs/02](../docs/02-kien-truc-he-thong.md).

```bash
flutter pub get
flutter run --dart-define=API_URL=http://localhost:8000/api/v1
flutter test                       # unit + widget test
flutter test integration_test      # E2E, cần Simulator đang chạy
```

Liquid Glass nằm trong plugin cục bộ [packages/liquid_glass](packages/liquid_glass/).
