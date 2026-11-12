import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/health/health_providers.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('Dashboard tính đúng trung bình biểu đồ nước trong 7 ngày', (
    tester,
  ) async {
    Map<String, dynamic>? trendQuery;
    final app = await pumpApp(
      tester,
      overrides: {
        'GET /stats/trend': (options) {
          trendQuery = Map<String, dynamic>.from(options.queryParameters);
          return const FakeResponse(200, {
            'metric': 'water',
            'unit': 'ml',
            'range': '7d',
            'from_date': '2026-11-03',
            'to_date': '2026-11-09',
            'points': [
              {'date': '2026-11-03', 'value': 100},
              {'date': '2026-11-04', 'value': null},
              {'date': '2026-11-05', 'value': 300},
              {'date': '2026-11-06', 'value': 400},
              {'date': '2026-11-07', 'value': 500},
              {'date': '2026-11-08', 'value': 600},
              {'date': '2026-11-09', 'value': 600},
            ],
          });
        },
      },
    );

    final chartAverage = find.textContaining('lít/ngày', findRichText: true);
    await tester.scrollUntilVisible(
      chartAverage,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tổng quan'), findsWidgets);
    expect(find.text('7 ngày qua'), findsOneWidget);
    expect(
      find.text('0,4 lít/ngày', findRichText: true),
      findsOneWidget,
      reason: '2.500 ml trong 7 ngày tương đương trung bình 0,4 lít/ngày',
    );
    expect(
      await app.container.read(bodyDataProvider.future),
      isA<BodyData>().having(
        (data) => data.waterByDay,
        'lượng nước mỗi ngày; null được xem là 0',
        [100, 0, 300, 400, 500, 600, 600],
      ),
    );
    expect(trendQuery, containsPair('metric', 'water'));
    expect(trendQuery, containsPair('range', '7d'));
    expect(app.backend.count('GET /stats/trend'), 1);
  });
}
