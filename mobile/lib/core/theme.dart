import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart' show LiquidGlassTabBar;

/// Màu và kiểu chữ dùng chung. Không hard-code màu trong màn hình, hãy lấy từ đây
/// hoặc qua `context.colors` để hỗ trợ cả Light Mode và Dark Mode.
abstract final class AppColors {
  // "Calm Health": nền đen tuyền kiểu Apple Fitness, thẻ xám than nổi lên bằng sắc nền chứ không bằng viền.
  static const background = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const cardHigh = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const ink = Color(0xFFF5F5F7);

  // Chữ phụ đạt >= 4.5:1 trên nền và thẻ
  static const inkSoft = Color(0xFF9E9EA6);

  // Màu nhấn của từng chỉ số (cũng là màu của vòng Activity Rings). Chỉ dùng để phân biệt
  // loại dữ liệu, không phải màu thương hiệu.
  static const steps = Color(0xFF30D158); // bước chân: xanh lá
  static const meds = Color(0xFFFF6F61); // thuốc (vòng thứ nhất): san hô
  static const sleep = Color(0xFFB39DFF); // giấc ngủ: tím nhạt
  static const water = Color(0xFF32D4E8); // nước uống: cyan
  static const weight = Color(0xFFFFB340); // cân nặng: vàng hổ phách ấm
  static const meal = Color(0xFFF26D9B); // bữa ăn: hồng
  static const medicine = Color(0xFF5AA9FF); // thuốc: xanh trời

  /// Màu thương hiệu: vàng. Dùng để tô nút chính, tab đang chọn, điểm nhấn. Chữ/icon đặt
  /// trên nền này phải dùng [onBrand]; chữ màu thương hiệu trên nền thường dùng `brandText`.
  static const brand = Color(0xFFFFD60A);
  static const onBrand = Color(0xFF1C1C1E);
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
    required this.backgroundSecondary,
    required this.textTertiary,
    required this.border,
    required this.onBrand,
    required this.brandText,
    required this.success,
    required this.warning,
    required this.disabled,
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

  /// Nền lõm phụ (ô nhập, vùng nhóm). Khác `card` là bề mặt nổi.
  final Color backgroundSecondary;

  /// Chữ thứ ba: chỉ cho chú thích không quan trọng, không dùng cho thông tin cần đọc.
  final Color textTertiary;
  final Color border;

  /// Chữ và icon đặt trên nền [brand].
  final Color onBrand;

  /// Chữ màu thương hiệu trên nền thường (đạt 4.5:1 ở cả sáng và tối).
  final Color brandText;
  final Color success;
  final Color warning;
  final Color disabled;

  /// Tên gọi theo vai trò, trùng với `card` và `cardHigh`.
  Color get surface => card;
  Color get surfaceElevated => cardHigh;

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
      AppColors.brand: brand,
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
    backgroundSecondary: Color(0xFF111113),
    textTertiary: Color(0xFF8E8E93),
    border: Color(0xFF48484A),
    onBrand: AppColors.onBrand,
    brandText: Color(0xFFFFD60A),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    disabled: Color(0xFF636366),
  );

  /// Bảng màu Light Mode kiểu Apple Health: nền xám nhạt, thẻ trắng. Màu nhấn đạt >= 4.5:1
  /// trên thẻ trắng và nền.
  static const light = AppColorPalette(
    isDark: false,
    background: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFE5E5EA),
    separator: Color(0xFFD1D1D6),
    ink: Color(0xFF1C1C1E),
    inkSoft: Color(0xFF58585E),
    steps: Color(0xFF1B7F37),
    meds: Color(0xFFC2412F),
    sleep: Color(0xFF5B45D6),
    water: Color(0xFF00758A),
    weight: Color(0xFF9A4F00),
    meal: Color(0xFFB8325F),
    medicine: Color(0xFF1559B8),
    brand: Color(0xFFFFC400),
    danger: Color(0xFFC62828),
    backgroundSecondary: Color(0xFFE9E9EF),
    textTertiary: Color(0xFF6C6C70),
    border: Color(0xFFC7C7CC),
    onBrand: Color(0xFF1C1C1E),
    brandText: Color(0xFF7A5700),
    success: Color(0xFF1E7F3A),
    warning: Color(0xFF9A5B00),
    disabled: Color(0xFFAEAEB2),
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
    Color? backgroundSecondary,
    Color? textTertiary,
    Color? border,
    Color? onBrand,
    Color? brandText,
    Color? success,
    Color? warning,
    Color? disabled,
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
    backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    border: border ?? this.border,
    onBrand: onBrand ?? this.onBrand,
    brandText: brandText ?? this.brandText,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    disabled: disabled ?? this.disabled,
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
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
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

  /// Kiểu chữ theo vai trò, đã có màu đúng của chế độ sáng/tối hiện tại.
  AppText get text => AppText(colors);
}

abstract final class AppRadius {
  static const card = 16.0;
  static const control = 12.0;
  static const sheet = 20.0;
  static const pill = 999.0;
}

/// Thang khoảng cách 4 / 8 / 12 / 16 / 20 / 24 / 32.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const ml = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Kích thước bố cục dùng chung.
abstract final class AppLayout {
  /// Đệm cuối danh sách để nội dung cuộn ra khỏi thanh tab nổi (gồm vùng home indicator).
  static double tabBarInset(BuildContext context) =>
      LiquidGlassTabBar.height + MediaQuery.viewPaddingOf(context).bottom + 16;
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

/// Gradient theo màu của từng chỉ số, dùng cho vòng, thanh và biểu đồ.
extension AccentX on Color {
  /// Từ màu gốc sang một sắc sáng hơn, đi theo chiều vòng cung.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(this, Colors.white, 0.2)!, this],
  );

  /// Vầng sáng mờ phía sau phần tử nổi bật. Thiết kế mới hạn chế dùng; giữ để tương thích.
  List<BoxShadow> get glow => [
    BoxShadow(color: withValues(alpha: 0.25), blurRadius: 16, spreadRadius: -4),
  ];
}

/// Chữ dùng font hệ thống (SF Pro trên iOS) để Dynamic Type và VoiceOver hoạt động chuẩn.
abstract final class AppFonts {
  /// Số liệu lớn: số có độ rộng đều để không nhảy khi đếm lên.
  static TextStyle number(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontSize: size,
    height: 1.0,
    color: color,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Kiểu chữ theo vai trò, màu lấy theo chế độ sáng/tối: `context.text.title`...
class AppText {
  const AppText(this.c);
  final AppColorPalette c;

  /// Tiêu đề lớn của màn hình.
  TextStyle get largeTitle => TextStyle(
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    color: c.ink,
  );

  /// Đầu mục trong màn hình.
  TextStyle get sectionTitle => TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: c.ink,
  );

  TextStyle get cardTitle => TextStyle(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: c.ink,
  );

  /// Con số chính của thẻ số liệu.
  TextStyle get metric => AppFonts.number(32, color: c.ink);

  TextStyle get body => TextStyle(fontSize: 17, height: 1.3, color: c.ink);

  TextStyle get secondary =>
      TextStyle(fontSize: 15, height: 1.3, color: c.inkSoft);

  TextStyle get caption =>
      TextStyle(fontSize: 13, height: 1.25, color: c.inkSoft);

  /// Chữ trên nút chính (nền vàng).
  TextStyle get button =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.onBrand);
}

/// Kiểu chữ tĩnh cũ, màu của Dark Mode. Màn hình mới nên dùng `context.text` để có màu đúng.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    color: AppColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static final metricValue = AppFonts.number(32);

  static const body = TextStyle(fontSize: 15, color: AppColors.ink);

  static const bodySoft = TextStyle(fontSize: 15, color: AppColors.inkSoft);

  static const caption = TextStyle(fontSize: 13, color: AppColors.inkSoft);

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.onBrand,
  );
}

abstract final class AppTheme {
  static ThemeData get dark => _build(AppColorPalette.dark, Brightness.dark);

  /// Giao diện Sáng (Light Mode) với độ tương phản WCAG AA.
  static ThemeData get light => _build(AppColorPalette.light, Brightness.light);

  static ThemeData _build(AppColorPalette p, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: p.brand,
      onPrimary: p.onBrand,
      secondary: p.brand,
      onSecondary: p.onBrand,
      error: p.danger,
      onError: Colors.white,
      surface: p.card,
      onSurface: p.ink,
      surfaceContainerHighest: p.cardHigh,
      onSurfaceVariant: p.inkSoft,
      outline: p.border,
      outlineVariant: p.separator,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      dividerColor: p.separator,
      dividerTheme: DividerThemeData(color: p.separator, thickness: 0.5),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.brandText),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.brand
              : (p.isDark ? const Color(0xFF39393D) : const Color(0xFFE0E0E5)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          minimumSize: const Size(0, 50),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.cardHigh,
        contentTextStyle: TextStyle(fontSize: 15, color: p.ink),
        shape: controlShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        modalBackgroundColor: p.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      extensions: [p],
    );
  }
}
