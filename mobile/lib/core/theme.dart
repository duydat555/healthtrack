import 'package:flutter/material.dart';

/// Màu và kiểu chữ dùng chung. Không hard-code màu trong màn hình, hãy lấy từ đây.
abstract final class AppColors {
  static const brand = Color(0xFF10B981);
  static const brandDark = Color(0xFF059669);
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF475569);
  static const backgroundTop = Color(0xFFECFDF5);
  static const backgroundBottom = Color(0xFFD1FAE5);
  static const danger = Color(0xFFEF4444);
}

abstract final class AppRadius {
  static const card = 24.0;
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.brand,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.brand,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
  );
}
