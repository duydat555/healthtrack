import 'package:flutter/material.dart';

class AppColors {
  // 1. Màu thương hiệu chính (Brand Colors)
  static const Color brandPrimary = Color(0xFF10B981); // Green/Teal thương hiệu

  static const Color brandDark = Color(
    0xFF047857,
  ); // Màu thương hiệu đậm hơn dùng cho nhãn/tab

  // 2. Màu chữ & Tương phản (Dành cho Issue #100)
  // Sử dụng inkSoft đậm hơn (Contrast >= 4.5:1) trên nền kính xanh nhạt
  static const Color inkPrimary = Color(0xFF1F2937); // Chữ chính (tối)
  static const Color inkSecondary = Color(0xFF4B5563); // Chữ phụ
  static const Color inkSoft = Color(
    0xFF374151,
  ); // Chữ phụ trên nền kính (đạt Contrast 4.5:1)

  // 3. Màu nhấn cho biểu tượng chỉ số (Dành cho Issue #101)
  static const Color waterAccent = Color(0xFF3B82F6); // Nước - Xanh dương
  static const Color sleepAccent = Color(0xFF8B5CF6); // Giấc ngủ - Tím
  static const Color stepsAccent = Color(0xFFF97316); // Bước chân - Cam
  static const Color heartAccent = Color(0xFFEF4444); // Nhịp tim - Đỏ

  // 4. Nền & Kính (Liquid Glass Backgrounds)
  static const Color glassBackground = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x66FFFFFF);
}
