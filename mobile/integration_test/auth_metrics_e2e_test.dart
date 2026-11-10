import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/token_storage.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// Chạy với backend local trên Android Emulator/thiết bị hoặc iOS Simulator.
/// Tạo tài khoản và chỉ số giả lập.
///
///   cd mobile
///   flutter test integration_test/auth_metrics_e2e_test.dart -d DEVICE_ID \
///     --dart-define=API_URL=http://10.0.2.2:8000/api/v1
/// iOS Simulator (macOS): dùng API_URL=http://localhost:8000/api/v1.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('đăng ký, đăng nhập và ghi cân nặng qua backend local', (
    tester,
  ) async {
    // Dọn phiên cũ khỏi vùng lưu trữ bảo mật để bắt đầu ở trạng thái đăng xuất.
    await SecureTokenStorage().clear();
    await tester.pumpWidget(
      const ProviderScope(retry: noRetry, child: HealthTrackApp()),
    );
    await settle(tester);
    expect(find.text('Đăng nhập'), findsWidgets);

    final runId = DateTime.now().microsecondsSinceEpoch;
    final email = 'e2e-$runId@healthtrack.example';
    const password = 'Test123456!';

    // 1. Đăng ký tài khoản giả lập. Ứng dụng tự đăng nhập sau khi đăng ký.
    await tester.tap(
      find.widgetWithText(TextButton, 'Chưa có tài khoản? Đăng ký'),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'E2E Test');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await settle(tester);
    expect(find.text('Hôm nay'), findsWidgets);

    // 2. Đăng xuất rồi đăng nhập lại để kiểm tra riêng endpoint đăng nhập.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final router = container.read(routerProvider);
    router.go('/profile');
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await settle(tester);
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await settle(tester);
    expect(find.text('Hôm nay'), findsWidgets);

    // 3. Ghi chỉ số cân nặng giả lập, rồi xác nhận giá trị xuất hiện trên Tổng quan.
    router.push('/add');
    await settle(tester);
    await tester.tap(find.text('Cân nặng'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '72.4');

    await tester.tap(find.widgetWithText(FilledButton, 'Ghi cân nặng'));
    await settle(tester);

    expect(find.text('72,4 kg', findRichText: true), findsOneWidget);

    // Không để lại token của tài khoản thử nghiệm trong vùng lưu trữ bảo mật trên thiết bị.
    router.go('/profile');
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await settle(tester);
    expect(await SecureTokenStorage().read(), isNull);
  });
}
