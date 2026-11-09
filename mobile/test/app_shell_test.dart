import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/main.dart';

void main() {
  setUp(() => appRouter.go('/'));

  testWidgets('chọn tab trên thanh tab đổi route của go_router', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, '/');

    await tester.tap(find.text('Mục tiêu'));
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, '/goals');

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, '/profile');
  });

  testWidgets('đổi route bằng code thì tab đang chọn cập nhật theo', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    appRouter.go('/metrics');
    await tester.pumpAndSettle();
    expect(find.text('Đang phát triển'), findsOneWidget);
    final bar = tester.widget<LiquidGlassTabBar>(
      find.byType(LiquidGlassTabBar),
    );
    expect(bar.currentIndex, 1);
  });

  testWidgets('nút nổi mở màn hình thêm nhanh', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, '/add');
  });
}
