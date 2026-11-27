import 'package:flutter/widgets.dart';

/// Bộ icon của app (Phosphor, font MIT trong assets/fonts; không dùng gói phosphor_flutter vì
/// bản 2.1.0 không biên dịch với Flutter 3.47), đặt tên theo ý nghĩa để màn hình không phụ thuộc tên icon cụ thể.
///
/// Quy ước: kiểu thường (regular) cho nút và hàng; kiểu đặc (fill) cho icon danh mục trong thẻ và
/// ô màu. Thanh tab native vẫn dùng SF Symbols của hệ thống.
abstract final class AppIcons {
  // Danh mục sức khỏe
  static const IconData water = IconData(0xe210, fontFamily: 'PhosphorRegular');
  static const IconData waterFill = IconData(
    0xe210,
    fontFamily: 'PhosphorFill',
  );
  static const IconData sleep = IconData(0xe330, fontFamily: 'PhosphorRegular');
  static const IconData sleepFill = IconData(
    0xe330,
    fontFamily: 'PhosphorFill',
  );
  static const IconData weight = IconData(
    0xe750,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData weightFill = IconData(
    0xe750,
    fontFamily: 'PhosphorFill',
  );
  static const IconData stepsFill = IconData(
    0xe73a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData bodyFill = IconData(0xe72e, fontFamily: 'PhosphorFill');
  static const IconData height = IconData(
    0xe6b8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData heightFill = IconData(
    0xe6b8,
    fontFamily: 'PhosphorFill',
  );
  static const IconData meal = IconData(0xe262, fontFamily: 'PhosphorRegular');
  static const IconData mealFill = IconData(0xe262, fontFamily: 'PhosphorFill');
  static const IconData medicine = IconData(
    0xe700,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData medicineFill = IconData(
    0xe700,
    fontFamily: 'PhosphorFill',
  );
  static const IconData pulseFill = IconData(
    0xe2ac,
    fontFamily: 'PhosphorFill',
  );
  static const IconData flameFill = IconData(
    0xe624,
    fontFamily: 'PhosphorFill',
  );
  static const IconData fireFill = IconData(0xe242, fontFamily: 'PhosphorFill');

  // Hành động và điều hướng
  static const IconData add = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const IconData arrowUp = IconData(0xe08e, fontFamily: 'PhosphorBold');
  static const IconData back = IconData(0xe138, fontFamily: 'PhosphorBold');
  static const IconData chevron = IconData(0xe13a, fontFamily: 'PhosphorBold');
  static const IconData check = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const IconData checkCircleFill = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  );
  static const IconData close = IconData(0xe4f6, fontFamily: 'PhosphorBold');
  static const IconData trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const IconData refresh = IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData restart = IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sliders = IconData(
    0xe434,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chat = IconData(0xe168, fontFamily: 'PhosphorRegular');
  static const IconData chart = IconData(0xe154, fontFamily: 'PhosphorRegular');
  static const IconData insights = IconData(
    0xe156,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData home = IconData(0xe2c2, fontFamily: 'PhosphorFill');

  // Hồ sơ và cài đặt
  static const IconData userFill = IconData(0xe4c2, fontFamily: 'PhosphorFill');
  static const IconData gender = IconData(0xe6e6, fontFamily: 'PhosphorFill');
  static const IconData cakeFill = IconData(0xe780, fontFamily: 'PhosphorFill');
  static const IconData calendar = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const IconData bellFill = IconData(0xe0ce, fontFamily: 'PhosphorFill');
  static const IconData heartFill = IconData(
    0xe2a8,
    fontFamily: 'PhosphorFill',
  );
  static const IconData lock = IconData(0xe2fa, fontFamily: 'PhosphorRegular');
  static const IconData lockFill = IconData(0xe2fa, fontFamily: 'PhosphorFill');

  // Huy hiệu, mục tiêu và trạng thái
  static const IconData star = IconData(0xe46a, fontFamily: 'PhosphorRegular');
  static const IconData starFill = IconData(0xe46a, fontFamily: 'PhosphorFill');
  static const IconData flag = IconData(0xe244, fontFamily: 'PhosphorRegular');
  static const IconData flagFill = IconData(0xe244, fontFamily: 'PhosphorFill');
  static const IconData medalFill = IconData(
    0xe320,
    fontFamily: 'PhosphorFill',
  );
  static const IconData sparkleFill = IconData(
    0xe6a2,
    fontFamily: 'PhosphorFill',
  );
  static const IconData inbox = IconData(0xe4aa, fontFamily: 'PhosphorRegular');
  static const IconData cloud = IconData(0xe1aa, fontFamily: 'PhosphorRegular');

  // Hoạt động ngoài trời
  static const IconData pause = IconData(0xe39e, fontFamily: 'PhosphorFill');
  static const IconData play = IconData(0xe3d0, fontFamily: 'PhosphorFill');
  static const IconData stop = IconData(0xe46c, fontFamily: 'PhosphorFill');
  static const IconData finishFlag = IconData(
    0xea38,
    fontFamily: 'PhosphorFill',
  );
  static const IconData layers = IconData(
    0xe466,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData locate = IconData(0xe1d6, fontFamily: 'PhosphorBold');
  static const IconData runFill = IconData(0xe730, fontFamily: 'PhosphorFill');
  static const IconData run = IconData(0xe730, fontFamily: 'PhosphorRegular');
  static const IconData walkFill = IconData(0xe73a, fontFamily: 'PhosphorFill');
  static const IconData walk = IconData(0xe73a, fontFamily: 'PhosphorRegular');
  static const IconData rideFill = IconData(0xe0d6, fontFamily: 'PhosphorFill');
  static const IconData ride = IconData(0xe0d6, fontFamily: 'PhosphorRegular');
  static const IconData route = IconData(0xe39c, fontFamily: 'PhosphorRegular');
  static const IconData mapPin = IconData(0xe316, fontFamily: 'PhosphorFill');
  static const IconData share = IconData(0xe408, fontFamily: 'PhosphorRegular');
  static const IconData timer = IconData(0xe492, fontFamily: 'PhosphorRegular');

  static const IconData wifiOff = IconData(
    0xe4f2,
    fontFamily: 'PhosphorRegular',
  );
}
