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
  static const inkSoft = Color(0xFF8E8E93);

  // Màu nhấn của từng chỉ số (cũng là màu của vòng Activity Rings)
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
