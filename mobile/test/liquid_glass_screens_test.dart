import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/widgets/liquid_glass_surfaces.dart';
import 'package:healthtrack/widgets/metric_card.dart';
import 'package:liquid_glass/liquid_glass.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('HomeScreen dùng LiquidGlass cho header, thẻ và bottom sheet', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(LiquidGlass), findsWidgets);
    expect(find.widgetWithText(LiquidGlassHeader, 'Tổng quan'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(MetricCard, 'Cân nặng'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsWidgets);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Đóng'), findsNothing);
  });

  testWidgets('MetricsScreen dùng LiquidGlass cho header và nhóm thẻ', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go('/metrics');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LiquidGlassHeader, 'Chỉ số'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsWidgets);
    expect(find.byType(LiquidGlassCardGroup), findsOneWidget);
  });

  testWidgets('GoalsScreen dùng LiquidGlass cho header, thẻ và bottom sheet', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go('/goals');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LiquidGlassHeader, 'Mục tiêu'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsWidgets);
    await tester.tap(find.text('Nước uống'));
    await tester.pumpAndSettle();

    expect(find.text('Mục tiêu nước uống'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hủy'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Lưu'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu nước uống'), findsNothing);
  });

  testWidgets(
    'ProfileScreen dùng LiquidGlass cho header, thẻ và bottom sheet',
    (tester) async {
      final app = await pumpApp(tester);
      app.container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(LiquidGlassHeader, 'Hồ sơ'), findsOneWidget);
      expect(find.byType(LiquidGlass), findsWidgets);
      expect(find.text('demo@healthtrack.example'), findsOneWidget);

      await tester.tap(find.text('Chiều cao'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Lưu'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
    },
  );
}
