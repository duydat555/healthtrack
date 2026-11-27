import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/api_client.dart';
import 'package:healthtrack/core/token_storage.dart';
import 'package:healthtrack/features/health/health_repository.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// E2E với backend cloud: đăng ký, ghi nước, xem biểu đồ và tạo nhắc trên app.
/// Chạy sau khi API reminders được triển khai lên cloud (backend có #68).
///
///   flutter test integration_test/cloud_core_flows_test.dart -d DEVICE_ID `
///     --dart-define=API_URL=https://api.example.com/api/v1
///
/// Tài khoản và log nước giả lập được giữ trên cloud; nhắc thử nghiệm được xóa.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('đăng ký, ghi nước, xem biểu đồ và đặt nhắc trên cloud', (
    tester,
  ) async {
    final apiUri = Uri.parse(apiBaseUrl);
    expect(
      apiUri.scheme,
      'https',
      reason: 'Chỉ chạy E2E cloud với URL HTTPS truyền qua API_URL.',
    );

    // Kiểm tra môi trường và API trước khi tạo dữ liệu trên backend dùng chung.
    final rootUri = apiUri.replace(path: '', query: null, fragment: null);
    final preflight = Dio(
      BaseOptions(
        baseUrl: rootUri.toString(),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final ready = await preflight.get<Map<String, dynamic>>(
      '/api/v1/health/ready',
    );
    expect(ready.statusCode, 200);
    expect(ready.data?['status'], 'ready');
    expect(ready.data?['database'], 'ok');

    final openApi = await preflight.get<Map<String, dynamic>>(
      '/api/v1/openapi.json',
    );
    final paths = openApi.data?['paths'] as Map<String, dynamic>? ?? {};
    expect(
      paths,
      contains('/api/v1/reminders'),
      reason: 'Backend cloud cần có API reminders theo issue #68.',
    );

    await SecureTokenStorage().clear();
    HealthRepository? cleanupRepository;
    int? testReminderId;
    addTearDown(() async {
      try {
        if (cleanupRepository != null && testReminderId != null) {
          await cleanupRepository.deleteReminder(testReminderId);
        }
      } finally {
        await SecureTokenStorage().clear();
      }
    });
    await tester.pumpWidget(
      const ProviderScope(retry: noRetry, child: HealthTrackApp()),
    );
    await settle(tester);
    expect(find.text('Đăng nhập'), findsWidgets);

    final email =
        'e2e-cloud-${DateTime.now().microsecondsSinceEpoch}@healthtrack.example';
    const password = 'Test123456!';

    // Đăng ký tài khoản giả lập; tài khoản mới được đưa tới onboarding.
    await tester.tap(
      find.widgetWithText(TextButton, 'Chưa có tài khoản? Đăng ký'),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'E2E Cloud Test');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await settle(tester);
    await tester.tap(find.text('Bỏ qua'));
    await settle(tester);
    expect(find.text('Hôm nay'), findsWidgets);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final router = container.read(routerProvider);
    final repository = container.read(healthRepositoryProvider);
    cleanupRepository = repository;

    // Ghi lượng nước giả lập qua form ứng dụng.
    router.push('/add');
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '777');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
    await settle(tester);

    // Biểu đồ được dựng trong danh sách cuộn của Dashboard.
    final dashboardScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('7 ngày qua'),
      300,
      scrollable: dashboardScroll,
    );
    expect(find.text('7 ngày qua'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('lít/ngày', findRichText: true),
      300,
      scrollable: dashboardScroll,
    );
    expect(
      find.textContaining('lít/ngày', findRichText: true),
      findsOneWidget,
      reason: 'Dashboard phải hiển thị biểu đồ xu hướng nước từ cloud.',
    );
    final trend = await repository.statsTrend('water');
    expect(trend, hasLength(7));
    expect(trend.last, 777);

    // Tạo nhắc bằng giao diện, rồi xác minh bản ghi qua API cloud.
    router.go('/profile');
    await settle(tester);
    await tester.tap(find.text('Nhắc nhở').last);
    await settle(tester);
    final remindersBefore = await repository.reminders();
    final oldIds = remindersBefore.map((reminder) => reminder.id).toSet();

    await tester.tap(find.byTooltip('Thêm nhắc nhở'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nhắc nhở'));
    await settle(tester);

    final remindersAfter = await repository.reminders();
    final createdReminders = remindersAfter
        .where((reminder) => !oldIds.contains(reminder.id))
        .toList();
    expect(createdReminders, hasLength(1));
    final testReminder = createdReminders.single;
    testReminderId = testReminder.id;
    expect(testReminder.kind, 'water');
    expect(testReminder.enabled, isTrue);
    expect(find.text('Uống nước · Đang bật'), findsOneWidget);
  });
}
