import 'package:flutter/material.dart';

/// Màu và kiểu chữ dùng chung. Không hard-code màu trong màn hình, hãy lấy từ đây
/// hoặc qua `context.colors` để hỗ trợ cả Light Mode và Dark Mode.
abstract final class AppColors {
  // Nền và chữ (Dark Mode mặc định theo phong cách Fitness)
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

/// Bảng màu động cho Light / Dark Mode đạt chuẩn tương phản WCAG AA (>= 4.5:1).
@immutable
class AppColorPalette extends ThemeExtension<AppColorPalette> {
  const AppColorPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.cardHigh,
    required this.separator,
    required this.ink,
    required this.inkSoft,
    required this.steps,
    required this.meds,
    required this.sleep,
    required this.water,
    required this.weight,
    required this.meal,
    required this.medicine,
    required this.brand,
    required this.danger,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color cardHigh;
  final Color separator;
  final Color ink;
  final Color inkSoft;
  final Color steps;
  final Color meds;
  final Color sleep;
  final Color water;
  final Color weight;
  final Color meal;
  final Color medicine;
  final Color brand;
  final Color danger;

  /// Đổi một màu nhấn của bảng màu tối (hằng `AppColors.x` khai báo ở cấp cao nhất, nơi không có
  /// `context`) sang màu tương ứng của bảng màu hiện tại. Màu lạ được giữ nguyên.
  Color adapt(Color c) {
    if (isDark) return c;
    final map = <Color, Color>{
      AppColors.steps: steps,
      AppColors.sleep: sleep,
      AppColors.water: water,
      AppColors.weight: weight,
      AppColors.meal: meal,
      AppColors.medicine: medicine,
      AppColors.danger: danger,
      AppColors.ink: ink,
      AppColors.inkSoft: inkSoft,
    };
    return map[c] ?? c;
  }

  static const dark = AppColorPalette(
    isDark: true,
    background: AppColors.background,
    card: AppColors.card,
    cardHigh: AppColors.cardHigh,
    separator: AppColors.separator,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    steps: AppColors.steps,
    meds: AppColors.meds,
    sleep: AppColors.sleep,
    water: AppColors.water,
    weight: AppColors.weight,
    meal: AppColors.meal,
    medicine: AppColors.medicine,
    brand: AppColors.brand,
    danger: AppColors.danger,
  );

  /// Bảng màu Light Mode chuẩn WCAG AA (>= 4.5:1 trên nền trắng #FFFFFF & xám nhạt #F2F2F7).
  static const light = AppColorPalette(
    isDark: false,
    background: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFE5E5EA),
    separator: Color(0xFFC6C6C8),
    ink: Color(0xFF111113),
    inkSoft: Color(0xFF48484A),
    steps: Color(0xFFC80A3D),
    meds: Color(0xFFC80A3D),
    sleep: Color(0xFF3B7A00),
    water: Color(0xFF007680),
    weight: Color(0xFF7E2FA3),
    meal: Color(0xFF9E4700),
    medicine: Color(0xFF005BB5),
    brand: Color(0xFFC80A3D),
    danger: Color(0xFFC62828),
  );

  @override
  AppColorPalette copyWith({
    bool? isDark,
    Color? background,
    Color? card,
    Color? cardHigh,
    Color? separator,
    Color? ink,
    Color? inkSoft,
    Color? steps,
    Color? meds,
    Color? sleep,
    Color? water,
    Color? weight,
    Color? meal,
    Color? medicine,
    Color? brand,
    Color? danger,
  }) => AppColorPalette(
    isDark: isDark ?? this.isDark,
    background: background ?? this.background,
    card: card ?? this.card,
    cardHigh: cardHigh ?? this.cardHigh,
    separator: separator ?? this.separator,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    steps: steps ?? this.steps,
    meds: meds ?? this.meds,
    sleep: sleep ?? this.sleep,
    water: water ?? this.water,
    weight: weight ?? this.weight,
    meal: meal ?? this.meal,
    medicine: medicine ?? this.medicine,
    brand: brand ?? this.brand,
    danger: danger ?? this.danger,
  );

  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) return this;
    return AppColorPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHigh: Color.lerp(cardHigh, other.cardHigh, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      steps: Color.lerp(steps, other.steps, t)!,
      meds: Color.lerp(meds, other.meds, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      water: Color.lerp(water, other.water, t)!,
      weight: Color.lerp(weight, other.weight, t)!,
      meal: Color.lerp(meal, other.meal, t)!,
      medicine: Color.lerp(medicine, other.medicine, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension ThemeContextX on BuildContext {
  AppColorPalette get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorPalette>() ??
        (theme.brightness == Brightness.light
            ? AppColorPalette.light
            : AppColorPalette.dark);
  }

  bool get isDark => colors.isDark;
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
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    extensions: const [AppColorPalette.dark],
  );

  /// Giao diện Sáng hỗ trợ chế độ hệ thống (Light Mode) với độ tương phản WCAG AA.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColorPalette.light.brand,
      brightness: Brightness.light,
    ).copyWith(surface: AppColorPalette.light.background),
    scaffoldBackgroundColor: AppColorPalette.light.background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColorPalette.light.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    extensions: const [AppColorPalette.light],
  );
}
