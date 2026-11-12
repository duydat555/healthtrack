import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/token_storage.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// E2E thật: app trên Simulator nói chuyện với backend đang chạy (`make up`) và đã seed (`make seed`).
///   cd mobile && flutter test integration_test/e2e_backend_test.dart -d THIET_BI \
///     --dart-define=API_URL=http://localhost:8200/api/v1
/// CẢNH BÁO: bài test xóa token đã lưu trong Keychain của app trên thiết bị đó.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets(
    'đăng nhập tài khoản demo, xem dữ liệu thật, ghi nước, đăng xuất',
    (tester) async {
      await SecureTokenStorage()
          .clear(); // bắt đầu từ trạng thái chưa đăng nhập
      await tester.pumpWidget(
        const ProviderScope(retry: noRetry, child: HealthTrackApp()),
      );
      await settle(tester);

      // 1. Chưa đăng nhập: thấy màn đăng nhập
      expect(find.text('Đăng nhập'), findsWidgets);

      // 2. Đăng nhập sai bị từ chối
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'demo@healthtrack.example',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'sai-mat-khau');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await settle(tester);
      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);

      // 3. Đăng nhập đúng: vào Tổng quan, có dữ liệu seed
      await tester.enterText(find.byType(TextFormField).at(1), 'demo12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await settle(tester);
      expect(find.text('Hôm nay'), findsWidgets);
      expect(find.text('N'), findsOneWidget); // "Người dùng Demo"
      // BMI 23 của người demo nằm trong khối "Chỉ số cơ thể", phía trên biểu đồ
      await tester.scrollUntilVisible(
        find.text('Bình thường'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bình thường'), findsWidgets);
      // Bố cục Tổng quan mới dựng danh sách theo cuộn: mục "7 ngày qua" nằm dưới màn hình
      await tester.scrollUntilVisible(
        find.text('7 ngày qua'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('7 ngày qua'), findsOneWidget);
      // Thẻ biểu đồ nằm dưới tiêu đề mục: cuộn tiếp tới khi dựng xong
      await tester.scrollUntilVisible(
        find.textContaining('lít/ngày', findRichText: true),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('lít/ngày', findRichText: true),
        findsOneWidget,
        reason: 'Dashboard phải hiển thị biểu đồ xu hướng nước từ backend',
      );

      // Thanh tab là view native trên iOS 26 nên Flutter không bấm được, điều hướng bằng router
      final router = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(routerProvider);

      // 4. Ghi thêm nước (màn của nút +)
      router.push('/add');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
      await settle(tester);
      expect(
        find.text('Hôm nay'),
        findsWidgets,
      ); // đã đóng màn thêm, về Tổng quan

      // 5. Đăng xuất
      router.go('/profile');
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
      await settle(tester);
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(await SecureTokenStorage().read(), isNull);
    },
  );
}
