import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/activity_rings.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('màn Tổng quan hiện vòng Activity Rings với dữ liệu từ API', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Hôm nay'), findsWidgets);
    // vòng 3 chỉ số hôm nay và vòng Health Score
    expect(find.byType(ActivityRings), findsNWidgets(2));
    // 500 + 300 ml nước hôm nay, mục tiêu mặc định 2 lít
    expect(find.textContaining('0,8', findRichText: true), findsWidgets);
    expect(find.textContaining('/2 lít', findRichText: true), findsOneWidget);
    // giấc ngủ 480 phút = 8 giờ
    expect(find.textContaining('/8 giờ', findRichText: true), findsOneWidget);
    // chữ cái đầu của "Người dùng Demo"
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets(
    'app gửi tz_offset của máy cho /stats để chia ngày theo giờ địa phương',
    (tester) async {
      final app = await pumpApp(tester);
      final expected = DateTime.now().timeZoneOffset.inMinutes;
      final summary = app.backend.requests.firstWhere(
        (r) => r.path == '/stats/summary',
      );
      final trend = app.backend.requests.firstWhere(
        (r) => r.path == '/stats/trend',
      );
      expect(summary.queryParameters['tz_offset'], expected);
      expect(trend.queryParameters['tz_offset'], expected);
      expect(trend.queryParameters['metric'], 'water');
    },
  );

  testWidgets(
    'ngày không có dữ liệu trong xu hướng nước được coi là 0 và không làm app lỗi',
    (tester) async {
      await pumpApp(tester);
      // fake trả null ở cột đầu; Tổng quan vẫn dựng được và có phần "7 ngày qua"
      await tester.scrollUntilVisible(find.text('7 ngày qua'), 300);
      expect(find.text('7 ngày qua'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
    },
  );

  testWidgets('mục tiêu từ /stats/summary quyết định đích của vòng', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: {
        'GET /stats/summary': (_) => const FakeResponse(200, {
          'date': '2026-11-09',
          'weight': null,
          'water_ml': 1000,
          'sleep_minutes': 0,
          'medications': {'taken': 1, 'missed': 0},
          'goals': [
            {
              'goal_id': 1,
              'metric': 'water',
              'period': 'daily',
              'unit': 'ml',
              'target_value': 2500.0,
              'current_value': 1000.0,
              'percent': 40.0,
              'achieved': false,
            },
          ],
        }),
      },
    );
    expect(find.textContaining('/2,5 lít', findRichText: true), findsOneWidget);
    // sleep_minutes = 0 nghĩa là chưa ghi giấc ngủ nào hôm nay
    expect(find.textContaining('--', findRichText: true), findsWidgets);
    // 1 thuốc đã uống, 1 thuốc đang dùng
    expect(find.textContaining('/1 liều', findRichText: true), findsOneWidget);
  });

  testWidgets('API lỗi mạng thì hiện thông báo và nút thử lại', (tester) async {
    await pumpApp(
      tester,
      overrides: {'GET /stats/summary': (_) => throw StateError('mất mạng')},
    );
    expect(find.text('Thử lại'), findsWidgets);
  });
}
