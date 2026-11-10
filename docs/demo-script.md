# Kịch bản demo HealthTrack trên Simulator / Emulator

> Tài liệu này mô tả từng bước quay video demo luồng lõi của ứng dụng HealthTrack  
> trên iOS Simulator (hoặc Android Emulator) phục vụ UAT và trình chiếu.

---

## 1. Yêu cầu môi trường

| Mục | Yêu cầu |
|-----|---------|
| **Thiết bị giả lập** | iPhone 16 Pro (iOS 18+) hoặc Pixel 8 Pro (Android 14+) |
| **Chế độ hiển thị** | Dark Mode bật (Settings → Display & Brightness → Dark) |
| **Ngôn ngữ** | Tiếng Anh hoặc Tiếng Việt |
| **Backend** | Cần kết nối được backend HealthTrack (local hoặc Render production) |
| **Thông báo** | Tắt tất cả notification trước khi quay (tránh popup làm gián đoạn) |
| **Do Not Disturb** | Bật trên Simulator: Settings → Focus → Do Not Disturb |

---

## 2. Khởi động ứng dụng

### Lệnh chạy iOS Simulator

```bash
# Từ thư mục gốc dự án
cd mobile
flutter run -d "iPhone 16 Pro"
```

Hoặc nếu dùng Makefile:

```bash
make mobile
```

### Lệnh chạy Android Emulator

```bash
flutter run -d "Pixel_8_Pro_API_35"
```

### Kiểm tra device ID khả dụng

```bash
flutter devices
```

---

## 3. Cài đặt ghi màn hình Simulator

### iOS – xcrun simctl (không cần thêm phần mềm)

```bash
# Bắt đầu ghi vào file demo.mov
xcrun simctl io booted recordVideo ~/Desktop/healthtrack-demo.mov

# Nhấn Ctrl+C để dừng ghi
```

### iOS – QuickTime Player (macOS)

1. Mở **QuickTime Player** → File → New Movie Recording
2. Nhấp vào mũi tên ▾ bên nút đỏ → chọn **iPhone Simulator** làm nguồn camera
3. Nhấn nút đỏ để bắt đầu ghi

### Android – Emulator Built-in

Nhấn biểu tượng **camera quay phim** trong thanh điều khiển của Android Studio Emulator.

---

## 4. Kịch bản quay video (~ 3–5 phút)

### 🎬 Bước 0 – Splash Screen (0:00–0:05)

- Khởi động app từ màn hình Home của Simulator
- Hiển thị SplashScreen (logo + loading indicator)
- Giữ 2–3 giây để người xem thấy branding

---

### 🔐 Bước 1 – Màn hình Đăng nhập (0:05–0:30)

- Màn hình `LoginScreen` hiện ra với nền đen, chữ trắng
- Điền email và mật khẩu demo:
  - **Email:** `demo@healthtrack.app`
  - **Password:** `Demo@1234`
- Nhấn **Đăng nhập**
- Chờ redirect sang màn Dashboard

> 💡 **Tip:** Nếu chưa có tài khoản, nhấn "Chưa có tài khoản? Đăng ký" để quay thêm luồng đăng ký (tùy chọn).

---

### 🏠 Bước 2 – Dashboard / Tổng quan (0:30–1:30)

- Màn hình `HomeScreen` với tab **Tổng quan** đang chọn
- **Điểm nhấn UI:**
  - Header ngày hôm nay (ví dụ: "Thứ Hai, 10/11")
  - Avatar chữ cái ở góc phải
  - **Activity Rings** (3 vòng màu: Nước uống xanh lam, Giấc ngủ xanh lá, Thuốc đỏ)
  - Số liệu: Nước uống / Giấc ngủ / Thuốc hôm nay
- **Thao tác quay:**
  1. Cuộn xuống chậm để thấy section "Chỉ số cơ thể" (4 MetricCard: Cân nặng, BMI, Giấc ngủ, Nước uống)
  2. Cuộn tiếp xuống để thấy biểu đồ cột "7 ngày qua – Nước uống"
  3. Kéo xuống để **pull-to-refresh** → xem indicator loading → data tươi

---

### 📊 Bước 3 – Tab Chỉ số / Metrics (1:30–2:15)

- Chạm vào tab **Chỉ số** (biểu tượng chart) ở thanh tab dưới
- Màn hình `MetricsScreen` với `LiquidGlassCardGroup` (3 thẻ kính: Nước uống, Giấc ngủ, Cân nặng)
- **Thao tác quay:**
  1. Chạm vào thẻ **Nước uống** → thẻ mở rộng (morph animation), hiện thêm chi tiết
  2. Chạm vào thẻ **Giấc ngủ** → tương tự
  3. Chạm vào thẻ **Cân nặng** → thấy BMI và nhận xét

---

### 🎯 Bước 4 – Tab Mục tiêu / Goals (2:15–3:00)

- Chạm vào tab **Mục tiêu** (biểu tượng flag) ở thanh tab dưới
- Màn hình `GoalsScreen` với 3 mục tiêu: Nước uống / Giấc ngủ / Cân nặng
- **Thao tác quay:**
  1. Thấy giá trị mục tiêu hiện tại (ví dụ: "2 lít/ngày")
  2. Chạm vào **Nước uống** → Dialog "Mục tiêu nước uống" mở ra
  3. Thay đổi giá trị (ví dụ: 2.5) → nhấn **Lưu**
  4. Thấy giá trị được cập nhật ngay trên tile

---

### 👤 Bước 5 – Tab Hồ sơ / Profile (3:00–3:30)

- Chạm vào tab **Hồ sơ** (biểu tượng person) ở thanh tab dưới
- Màn hình `ProfileScreen` hiển thị:
  - Avatar chữ cái + Tên + Email
  - Dòng **Chiều cao** (nếu chưa đặt: "Chưa đặt")
- **Thao tác quay:**
  1. Chạm vào **Chiều cao** → Dialog "Chiều cao" mở ra
  2. Nhập `170` → nhấn **Lưu**
  3. Thấy chiều cao được cập nhật ("170 cm")

---

### ➕ Bước 6 – Màn hình Thêm nhanh / Add (3:30–4:30)

- Chạm vào nút **+** ở giữa thanh tab dưới
- Màn hình `AddScreen` hiện lên dạng modal
- **Thao tác quay:**
  1. **Nước** (đang chọn mặc định): chọn chip "250 ml" → nhấn "Thêm nước" → Snackbar xác nhận
  2. Chạm chip **Cân nặng**: nhập `68.5` → nhấn "Ghi cân nặng" → Snackbar xác nhận
  3. Chạm chip **Ngủ**: chọn giờ đi ngủ (23:00), giờ dậy (06:30), 4 sao chất lượng → nhấn "Ghi giấc ngủ"
  4. Chạm chip **Thuốc**: thấy danh sách thuốc, nhấn "Đã uống" trên một thuốc
  5. Nhấn **X** (close) để đóng modal
- Quay lại màn Tổng quan → thấy Activity Rings đã cập nhật giá trị mới

---

### 🚪 Bước 7 – Đăng xuất (4:30–4:45)

- Vào tab **Hồ sơ**
- Cuộn xuống, nhấn nút **Đăng xuất** (đỏ)
- Dialog xác nhận "Đăng xuất?" → nhấn **Đăng xuất**
- App redirect về màn `LoginScreen`

---

## 5. Các lưu ý khi quay

- **Tốc độ:** Thao tác chậm, dừng 1–2 giây ở mỗi màn hình để người xem kịp đọc
- **Animation:** Chờ animation (Activity Rings, morph card) chạy xong mới chuyển màn
- **Lỗi mạng:** Nếu gặp lỗi "Không thể kết nối", đảm bảo backend đang chạy và `API_BASE_URL` trỏ đúng địa chỉ
- **Dark Mode:** Luôn quay ở Dark Mode để thể hiện đúng thiết kế Liquid Glass
- **Độ phân giải:** Xuất video ở độ phân giải gốc của Simulator (không cần scale down)

---

## 6. Hậu kỳ (tùy chọn)

| Công cụ | Tác dụng |
|---------|---------|
| **QuickTime** | Trim đầu/cuối video |
| **iMovie** | Thêm title card, fade in/out |
| **FFmpeg** | Chuyển `.mov` → `.mp4`: `ffmpeg -i demo.mov -c:v libx264 demo.mp4` |
| **Gifski** | Tạo GIF từ video: `gifski -o demo.gif --fps 20 demo.mov` |

---

*Tài liệu này được tạo theo Task #85 – UAT UI Bug Fix & Demo Script.*  
*Cập nhật lần cuối: 2026-11-10*
