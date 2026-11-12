# Kiến trúc Mobile & Cấu trúc Feature-First

Tài liệu này chốt cấu trúc mã nguồn Flutter (`mobile/`) theo mô hình **feature-first**, hướng dẫn thiết lập môi trường và quy trình chạy/kiểm thử ứng dụng HealthTrack trên Simulator/Emulator.

---

## 1. Môi trường phát triển & Khởi chạy

### Yêu cầu công cụ

| Thành phần | Phiên bản / Yêu cầu | Ghi chú |
|---|---|---|
| **Flutter SDK** | `>= 3.47.x` (channel `stable`) | Kèm Dart SDK `^3.13.7` |
| **iOS (macOS)** | Xcode + iOS Simulator (iPhone SE / iPhone Pro / Pro Max) | Hỗ trợ hiệu ứng Liquid Glass native trên iOS 26+ |
| **Android** | Android SDK (API 35+) & Android Emulator | Ví dụ `Pixel_7_API_35`, `Pixel_4_API_33` |

### Kiểm tra môi trường

```bash
cd mobile
flutter doctor -v
flutter devices
flutter emulators
```

### Khởi chạy trên Simulator / Emulator

1. Khởi động Simulator (macOS) hoặc Android Emulator:
   ```bash
   # Android Emulator
   flutter emulators --launch Pixel_7_API_35
   ```
2. Chạy ứng dụng:
   ```bash
   cd mobile
   flutter pub get

   # Kết nối backend local (iOS Simulator: 127.0.0.1, Android Emulator: 10.0.2.2)
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
   ```
3. Mở nhanh một route cụ thể khi debug UI:
   ```bash
   flutter run --dart-define=INITIAL_ROUTE=/metrics
   ```

---

## 2. Cấu trúc thư mục `mobile/lib/` (Feature-First)

Toàn bộ mã nguồn Flutter được tổ chức theo **feature-first** (gom UI, state, logic theo từng tính năng nghiệp vụ thay vì chia phẳng toàn app theo layer kỹ thuật):

```text
mobile/
├── lib/
│   ├── main.dart                     # Điểm khởi chạy app, cấu hình ProviderScope & HealthTrackApp
│   ├── app/                          # Vỏ ứng dụng & điều hướng toàn cục
│   │   ├── app_shell.dart            # Khung 4 tab chính + LiquidGlassTabBar + nút +
│   │   └── router.dart               # Cấu hình GoRouter (StatefulShellRoute.indexedStack, redirect auth)
│   ├── core/                         # Hạ tầng & tiện ích dùng chung toàn app (không phụ thuộc feature)
│   │   ├── core.dart                 # Barrel file export các module core
│   │   ├── api_client.dart           # Cấu hình Dio, baseUrl, AuthInterceptor (auto refresh token)
│   │   ├── format.dart               # Định dạng số, ngày, thời lượng kiểu Việt Nam & phân loại BMI
│   │   ├── theme.dart                # AppColors, AppRadius, AppTheme (nguồn chân lý duy nhất cho theme)
│   │   └── token_storage.dart        # Lưu access/refresh token an toàn bằng flutter_secure_storage
│   ├── widgets/                      # Bộ widget nền UI thuần túy dùng lại ở nhiều feature
│   │   ├── activity_rings.dart       # Vòng tròn tiến độ Activity Rings
│   │   ├── app_form.dart             # AppTextField, PrimaryButton, ErrorText, validateEmail
│   │   ├── metric_card.dart          # Thẻ chỉ số kèm biểu đồ sparkline
│   │   └── section_header.dart       # Tiêu đề phân mục kèm ngữ nghĩa header
│   └── features/                     # Các tính năng độc lập (Feature-First)
│       ├── add/
│       │   └── add_screen.dart       # Màn ghi nhanh: nước, cân nặng, giấc ngủ, thuốc, bước chân, bữa ăn
│       ├── auth/
│       │   ├── auth_controller.dart  # AuthController (Riverpod AsyncNotifier)
│       │   ├── auth_repository.dart  # Gọi /auth/login, /auth/register, /users/me
│       │   ├── auth_screens.dart     # LoginScreen, RegisterScreen, SplashScreen
│       │   └── user.dart             # Model User
│       ├── goals/
│       │   └── goals_screen.dart     # Quản lý mục tiêu cá nhân (nước, giấc ngủ, cân nặng)
│       ├── health/
│       │   ├── health_providers.dart # TodaySummary, BodyData & Riverpod providers
│       │   ├── health_repository.dart# Repository gọi CRUD chỉ số sức khỏe & thống kê
│       │   └── models.dart           # WeightLog, WaterLog, SleepLog, StepLog, MealLog, Goal, Medication
│       ├── home/
│       │   └── home_screen.dart      # Dashboard Tổng quan (Activity Rings, lưới chỉ số, biểu đồ nước 7 ngày)
│       ├── metrics/
│       │   └── metrics_screen.dart   # Màn Chỉ số sử dụng LiquidGlassCardGroup
│       ├── placeholder/
│       │   └── placeholder_screen.dart # Màn giữ chỗ cho tính năng đang phát triển
│       └── profile/
│           └── profile_screen.dart   # Hồ sơ người dùng, cập nhật chiều cao & đăng xuất
└── packages/
    └── liquid_glass/                 # Plugin cục bộ cầu nối Liquid Glass iOS 26+ & BackdropFilter fallback
```

---

## 3. Quy tắc kiến trúc & Luồng dữ liệu

### Nguyên tắc phụ thuộc giữa các tầng

1. **`features/<tên>`** chỉ import từ `core/`, `widgets/`, `packages/` và các domain model/provider dùng chung (ví dụ `auth/`, `health/`). Không để `core/` hoặc `widgets/` phụ thuộc ngược vào `features/`.
2. **Màu sắc & bo góc**: luôn lấy từ `AppColors` và `AppRadius` trong `lib/core/theme.dart`; không giữ file màu trùng lặp hoặc hard-code mã màu trực tiếp trong màn hình.
3. **Nền kính Liquid Glass**: chỉ áp dụng cho lớp điều hướng (`LiquidGlassTabBar`) và nhóm thẻ nổi bật (`LiquidGlassCardGroup`); tránh bọc quá nhiều `UiKitView` bên trong danh sách cuộn dài.

### Luồng dữ liệu (State & API)

```text
Screen (ConsumerWidget / ConsumerStatefulWidget)
   │  ref.watch(...)
   ▼
Riverpod Providers (authProvider, todaySummaryProvider, bodyDataProvider, ...)
   │  gọi hàm nghiệp vụ
   ▼
Repository (AuthRepository, HealthRepository)
   │  HTTP JSON qua Dio + AuthInterceptor (tự refresh token khi 401)
   ▼
FastAPI Backend (/api/v1/*)
```

---

## 4. Kiểm tra chất lượng cục bộ & CI

Trước khi tạo Pull Request, luôn chạy đủ 3 bước kiểm tra:

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test integration_test packages/liquid_glass/lib packages/liquid_glass/test
flutter analyze
flutter test
```

> **Lưu ý trên Windows:** Các bài test Golden (`test/foundation_widgets_test.dart`) được sinh trên môi trường Linux khớp với GitHub Actions CI, có thể sai khác nhẹ về anti-aliasing font khi chạy cục bộ trên Windows. Không ghi đè file golden từ Windows.
