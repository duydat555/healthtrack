import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/token_storage.dart';
import 'package:healthtrack/features/health/health_providers.dart';
import 'package:healthtrack/features/health/health_repository.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// E2E Dashboard với backend local; tạo tài khoản và dữ liệu sức khỏe giả riêng cho lần chạy.
/// Android Emulator:
///   cd mobile && flutter test integration_test/dashboard_e2e_test.dart -d emulator-5554 \
///     --dart-define=API_URL=http://10.0.2.2:8000/api/v1
/// iOS Simulator dùng API_URL=http://localhost:8000/api/v1.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('Dashboard hiển thị đúng biểu đồ nước 7 ngày từ backend', (
    tester,
  ) async {
    await SecureTokenStorage().clear();
    await tester.pumpWidget(
      const ProviderScope(retry: noRetry, child: HealthTrackApp()),
    );
    await settle(tester);
    expect(find.text('Đăng nhập'), findsWidgets);

    final email =
        'dashboard-e2e-${DateTime.now().microsecondsSinceEpoch}@healthtrack.example';
    const password = 'Test123456!';
    await tester.tap(
      find.widgetWithText(TextButton, 'Chưa có tài khoản? Đăng ký'),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Dashboard E2E');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await settle(tester);
    expect(find.text('Hôm nay'), findsWidgets);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final repository = container.read(healthRepositoryProvider);
    final today = DateTime.now();
    const dailyMl = [100, null, 300, 400, 500, 600, 600];
    for (var i = 0; i < dailyMl.length; i++) {
      final amount = dailyMl[i];
      if (amount == null) continue;
      final day = DateTime(
        today.year,
        today.month,
        today.day,
        12,
      ).subtract(Duration(days: dailyMl.length - i - 1));
      await repository.addWater(amount, at: day);
    }

    container.invalidate(bodyDataProvider);
    final body = await container.read(bodyDataProvider.future);
    expect(body.waterByDay, [100, 0, 300, 400, 500, 600, 600]);
    await tester.pumpAndSettle();

    final chartAverage = find.text('0,4 lít/ngày', findRichText: true);
    await tester.scrollUntilVisible(
      chartAverage,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('7 ngày qua'), findsOneWidget);
    expect(chartAverage, findsOneWidget);

    final router = container.read(routerProvider);
    router.go('/profile');
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await settle(tester);
    expect(await SecureTokenStorage().read(), isNull);
  });
}
