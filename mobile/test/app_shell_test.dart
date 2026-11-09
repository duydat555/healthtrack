import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/features/goals/goals_screen.dart';
import 'package:healthtrack/features/metrics/metrics_screen.dart';
import 'package:liquid_glass/liquid_glass.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('chọn tab trên thanh tab đổi route của go_router', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final router = app.container.read(routerProvider);
    expect(router.state.uri.path, '/');

    await tester.tap(find.text('Mục tiêu'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/goals');
    expect(find.byType(GoalsScreen), findsOneWidget);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(find.text('demo@healthtrack.example'), findsOneWidget);
  });

  testWidgets('đổi route bằng code thì tab đang chọn cập nhật theo', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go('/metrics');
    await tester.pumpAndSettle();
    expect(find.byType(MetricsScreen), findsOneWidget);
    final bar = tester.widget<LiquidGlassTabBar>(
      find.byType(LiquidGlassTabBar),
    );
    expect(bar.currentIndex, 1);
  });

  testWidgets('nút nổi mở màn hình thêm nhanh', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(app.container.read(routerProvider).state.uri.path, '/add');
  });
}
