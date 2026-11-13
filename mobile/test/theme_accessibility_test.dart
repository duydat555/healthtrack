import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/home/home_screen.dart';
import 'package:healthtrack/widgets/core_widgets.dart';

import 'helpers/fake_backend.dart';

double _contrastRatio(Color foreground, Color background) {
  final l1 = foreground.computeLuminance();
  final l2 = background.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('màu chữ và màu nhấn Light/Dark Mode đạt chuẩn tương phản WCAG AA (>= 4.5:1)', () {
    for (final palette in const [AppColorPalette.light, AppColorPalette.dark]) {
      // Chữ trên nền và trên thẻ
      for (final text in [palette.ink, palette.inkSoft, palette.brandText]) {
        expect(
          _contrastRatio(text, palette.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrastRatio(text, palette.card), greaterThanOrEqualTo(4.5));
      }
      // Chữ trên nền vàng thương hiệu
      expect(
        _contrastRatio(palette.onBrand, palette.brand),
        greaterThanOrEqualTo(4.5),
      );
      // Màu nhấn của chỉ số khi dùng làm chữ hoặc nét vẽ
      for (final accent in [
        palette.steps,
        palette.meds,
        palette.water,
        palette.sleep,
        palette.weight,
        palette.meal,
        palette.medicine,
        palette.danger,
        palette.success,
        palette.warning,
      ]) {
        expect(
          _contrastRatio(accent, palette.card),
          greaterThanOrEqualTo(4.5),
          reason: 'accent $accent trên thẻ ${palette.isDark ? "tối" : "sáng"}',
        );
        expect(
          _contrastRatio(accent, palette.background),
          greaterThanOrEqualTo(4.5),
          reason: 'accent $accent trên nền ${palette.isDark ? "tối" : "sáng"}',
        );
      }
    }
  });

  testWidgets('app cấu hình ThemeMode.system và thích ứng Light/Dark Mode', (
    tester,
  ) async {
    await pumpApp(tester);
    final mat = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(mat.themeMode, ThemeMode.system);
    expect(mat.theme?.brightness, Brightness.light);
    expect(mat.darkTheme?.brightness, Brightness.dark);

    // Giả lập hệ thống chuyển sang Light Mode
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();

    final homeCtx = tester.element(find.byType(HomeScreen));
    expect(homeCtx.isDark, isFalse);
    expect(homeCtx.colors.background, AppColorPalette.light.background);
  });

  testWidgets(
    'Dynamic Type phóng chữ 2.0x trên Home, Mục tiêu, Hồ sơ, Thêm nhanh không lỗi overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final app = await pumpApp(tester);
      expect(tester.takeException(), isNull);

      app.container.read(routerProvider).go('/goals');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      app.container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      app.container.read(routerProvider).push('/add');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LoadingState, ErrorState, EmptyState dùng đúng màu theme và Semantics',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                const LoadingState(useSkeleton: false),
                ErrorState(message: 'Lỗi mạng', onRetry: () => retried = true),
                const EmptyState(message: 'Không có dữ liệu'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
    },
  );
}
