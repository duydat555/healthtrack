import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

Future<void> _openTrends(WidgetTester tester) async {
  await tester.tap(find.text('Chỉ số'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Xem biểu đồ xu hướng'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'màn Xu hướng dựng BarChart cho nước và đổi khoảng 7/30/90 ngày qua Segmented Control',
    (tester) async {
      final app = await pumpApp(
        tester,
        overrides: {
          'GET /stats/trend': (req) {
            final range = (req.queryParameters['range'] as String?) ?? '7d';
            final count = range == '90d' ? 90 : (range == '30d' ? 30 : 7);
            return FakeResponse(200, {
              'metric': req.queryParameters['metric'] ?? 'water',
              'unit': 'ml',
              'range': range,
              'from_date': '2026-10-01',
              'to_date': '2026-11-11',
              'points': [
                for (var i = 0; i < count; i++)
                  {'date': '2026-11-01', 'value': (i % 3 + 1) * 500},
              ],
            });
          },
        },
      );

      await _openTrends(tester);

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Trung bình'), findsOneWidget);
      expect(find.text('Cao nhất'), findsOneWidget);
      expect(find.text('Thấp nhất'), findsOneWidget);

      await tester.tap(find.text('30 ngày'));
      await tester.pumpAndSettle();
      expect(
        app.backend.requests.any(
          (r) =>
              r.path == '/stats/trend' && r.queryParameters['range'] == '30d',
        ),
        isTrue,
      );

      await tester.tap(find.text('90 ngày'));
      await tester.pumpAndSettle();
      expect(
        app.backend.requests.any(
          (r) =>
              r.path == '/stats/trend' && r.queryParameters['range'] == '90d',
        ),
        isTrue,
      );
    },
  );

  testWidgets('chọn Giấc ngủ dựng LineChart từ fl_chart', (tester) async {
    final app = await pumpApp(
      tester,
      overrides: {
        'GET /stats/trend': (req) => FakeResponse(200, {
          'metric': req.queryParameters['metric'] ?? 'water',
          'unit': 'minutes',
          'range': req.queryParameters['range'] ?? '7d',
          'points': [
            for (var i = 0; i < 7; i++)
              {'date': '2026-11-0${1 + i}', 'value': 480},
          ],
        }),
      },
    );

    await _openTrends(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Giấc ngủ'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('8 giờ'), findsWidgets);
    expect(
      app.backend.requests.any(
        (r) =>
            r.path == '/stats/trend' && r.queryParameters['metric'] == 'sleep',
      ),
      isTrue,
    );
  });

  testWidgets(
    'hiển thị trạng thái rỗng, trạng thái lỗi có Thử lại và Semantics chuẩn',
    (tester) async {
      final handle = tester.ensureSemantics();
      var shouldFail = true;
      var returnEmpty = false;
      await pumpApp(
        tester,
        overrides: {
          'GET /stats/trend': (req) {
            // HomeScreen tải water trước; khi vào màn Xu hướng với metric=steps thì test fail/empty
            if (req.queryParameters['metric'] == 'steps') {
              if (shouldFail) {
                return const FakeResponse(500, {'detail': 'Lỗi máy chủ'});
              }
              if (returnEmpty) {
                return const FakeResponse(200, {
                  'metric': 'steps',
                  'unit': 'steps',
                  'range': '7d',
                  'points': [
                    {'date': '2026-11-10', 'value': null},
                    {'date': '2026-11-11', 'value': null},
                  ],
                });
              }
            }
            return const FakeResponse(200, {
              'metric': 'water',
              'unit': 'ml',
              'range': '7d',
              'points': [
                {'date': '2026-11-10', 'value': 1000},
                {'date': '2026-11-11', 'value': 1500},
              ],
            });
          },
        },
      );

      await _openTrends(tester);
      expect(
        find.bySemanticsLabel(RegExp('Khoảng thời gian 7 ngày')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Bước chân'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);

      shouldFail = false;
      returnEmpty = true;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có dữ liệu Bước chân'), findsOneWidget);
      handle.dispose();
    },
  );
}
