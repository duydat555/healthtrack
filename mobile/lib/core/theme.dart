import 'package:flutter/material.dart';

/// Màu và kiểu chữ dùng chung. Không hard-code màu trong màn hình, hãy lấy từ đây.
/// Phong cách theo app Fitness của Apple: nền đen, thẻ xám đậm, màu nhấn rực cho từng chỉ số.
abstract final class AppColors {
  // Nền và chữ
  static const background = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const cardHigh = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const ink = Color(0xFFFFFFFF);

  // Issue #100: Tăng độ tương phản chữ phụ/nhãn tab (xám sáng hơn đạt contrast >= 4.5:1)
  static const inkSoft = Color(0xFFD1D1D6);

  // Issue #101: Màu nhấn của từng chỉ số (cũng là màu của vòng Activity Rings)
  static const steps = Color(0xFFFA114F); // bước chân
  static const meds = Color(0xFFFA114F); // thuốc (cùng màu vòng thứ nhất)
  static const sleep = Color(0xFFA3F73B); // giấc ngủ
  static const water = Color(0xFF1EEAEF); // nước uống
  static const weight = Color(0xFFBF5AF2); // cân nặng
  static const meal = Color(0xFFFF9F0A); // bữa ăn
  static const medicine = Color(0xFF0A84FF); // thuốc

  /// Màu thương hiệu: nút nổi, tab đang chọn.
  static const brand = steps;
  static const danger = Color(0xFFFF453A);
}

abstract final class AppRadius {
  static const card = 20.0;
  static const control = 14.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// Hệ thống kiểu chữ chuẩn hóa cho toàn bộ ứng dụng.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const metricValue = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const body = TextStyle(fontSize: 15, color: AppColors.ink);

  static const bodySoft = TextStyle(fontSize: 15, color: AppColors.inkSoft);

  static const caption = TextStyle(fontSize: 13, color: AppColors.inkSoft);

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.background),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );

  /// App hiện chỉ có giao diện tối (giống Fitness). Giữ `light` để MaterialApp không lỗi.
  static ThemeData get light => dark;
}
