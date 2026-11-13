import 'package:flutter/material.dart';

/// Màu và kiểu chữ dùng chung. Không hard-code màu trong màn hình, hãy lấy từ đây
/// hoặc qua `context.colors` để hỗ trợ cả Light Mode và Dark Mode.
abstract final class AppColors {
  // Nền và chữ (Dark Mode mặc định theo phong cách Fitness)
  // "Mực biển": nền xanh đêm thay cho đen tuyền, thẻ nổi lên bằng sắc xanh chứ không bằng viền.
  static const background = Color(0xFF0A1A2A);
  static const card = Color(0xFF12293D);
  static const cardHigh = Color(0xFF1B3A55);
  static const separator = Color(0xFF2A4A66);
  static const ink = Color(0xFFF2F7F5);

  // Issue #100: Tăng độ tương phản chữ phụ/nhãn tab (xám sáng hơn đạt contrast >= 4.5:1)
  static const inkSoft = Color(0xFF9FB6C4);

  // Issue #101: Màu nhấn của từng chỉ số (cũng là màu của vòng Activity Rings)
  static const steps = Color(0xFFFF8A4C); // bước chân: cam hổ phách
  static const meds = Color(0xFFFF6F61); // thuốc (vòng thứ nhất): san hô
  static const sleep = Color(0xFFA08CFF); // giấc ngủ: tím phấn
  static const water = Color(0xFF38D6C9); // nước uống: ngọc lam
  static const weight = Color(0xFFE8C547); // cân nặng: vàng nắng
  static const meal = Color(0xFFF26D9B); // bữa ăn: hồng cánh sen
  static const medicine = Color(0xFF5AA9FF); // thuốc: xanh trời

  /// Màu thương hiệu: nút nổi, tab đang chọn. Chữ trắng trên màu này đạt 4.5:1.
  static const brand = Color(0xFFD93A2E);
  static const danger = Color(0xFFFF6B6B);
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
      AppColors.meds: meds,
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
    background: Color(0xFFEEF4F3),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFDCE8E6),
    separator: Color(0xFFC3D3D0),
    ink: Color(0xFF0C2233),
    inkSoft: Color(0xFF3F5A6B),
    steps: Color(0xFFB2470F),
    meds: Color(0xFFC2412F),
    sleep: Color(0xFF5B45D6),
    water: Color(0xFF00796F),
    weight: Color(0xFF8A6A00),
    meal: Color(0xFFB8325F),
    medicine: Color(0xFF1559B8),
    brand: Color(0xFFC2412F),
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

/// Chuyển động có chủ đích: chỉ dùng để báo điều gì vừa thay đổi (vòng đầy lên, số đếm, xác nhận ghi).
/// Màn hình tôn trọng cài đặt Giảm chuyển động qua [AppMotion.of].
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 900);
  static const curve = Curves.easeOutCubic;

  /// Thời lượng thực tế: bằng 0 khi người dùng bật Giảm chuyển động.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Gradient và vầng sáng theo màu của từng chỉ số, dùng cho vòng, thanh và biểu đồ.
extension AccentX on Color {
  /// Từ màu gốc sang một sắc sáng hơn, đi theo chiều vòng cung.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(this, Colors.white, 0.28)!,
      this,
    ],
  );

  /// Vầng sáng mờ phía sau phần tử nổi bật (chỉ dùng ở Dark Mode).
  List<BoxShadow> get glow => [
    BoxShadow(color: withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -4),
  ];
}

/// Họ chữ hiển thị: Bricolage Grotesque (OFL, có tiếng Việt) cho tiêu đề và số liệu.
/// Chữ thân dùng font hệ thống để Dynamic Type và VoiceOver hoạt động chuẩn.
abstract final class AppFonts {
  static const display = 'BricolageGrotesque';

  /// Trục độ đậm và độ hẹp của font biến thiên.
  static List<FontVariation> variation({double weight = 700, double width = 100}) => [
    FontVariation('wght', weight),
    FontVariation('wdth', width),
    const FontVariation('opsz', 48),
  ];

  /// Số liệu lớn: số có độ rộng đều để không nhảy khi đếm lên.
  static TextStyle number(double size, {Color color = AppColors.ink}) => TextStyle(
    fontFamily: display,
    fontSize: size,
    height: 1.0,
    color: color,
    fontVariations: variation(weight: 760, width: 92),
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Hệ thống kiểu chữ chuẩn hóa cho toàn bộ ứng dụng.
abstract final class AppTextStyles {
  static final pageTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 36,
    height: 1.05,
    letterSpacing: -0.5,
    fontVariations: AppFonts.variation(weight: 780, width: 90),
    color: AppColors.ink,
  );

  static final sectionTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 22,
    height: 1.15,
    fontVariations: AppFonts.variation(weight: 700, width: 95),
    color: AppColors.ink,
  );

  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static final metricValue = AppFonts.number(34);

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
