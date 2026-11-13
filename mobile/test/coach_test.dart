import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/features/health/health_providers.dart';

import 'helpers/fake_backend.dart';

String sse(List<String> events) =>
    '${events.map((e) => 'data: $e').join('\n\n')}\n\n';

Future<void> openCoach(WidgetTester tester) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(routerProvider)
      .push('/coach');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Tổng quan hiện Nhận xét tuần của Coach', (tester) async {
    await pumpApp(
      tester,
      overrides: {
        'GET /coach/weekly': (_) => const FakeResponse(200, {
          'week_start': '2026-11-09',
          'content': 'Tuần ổn, bạn uống nước đều.',
          'model': 'claude-sonnet-5-5',
        }),
      },
    );
    expect(find.text('Nhận xét tuần'), findsOneWidget);
    expect(find.text('Tuần ổn, bạn uống nước đều.'), findsOneWidget);
  });

  testWidgets('thẻ Nhận xét tuần ẩn khi Coach chưa được bật (503)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: {
        'GET /coach/weekly': (_) => const FakeResponse(503, {
          'detail': 'AI Coach chưa được bật trên máy chủ',
        }),
      },
    );
    expect(find.text('Nhận xét tuần'), findsNothing);
  });

  testWidgets(
    'chat: câu trả lời hiện ra, Coach ghi hộ và app tải lại dữ liệu',
    (tester) async {
      final app = await pumpApp(
        tester,
        overrides: {
          'POST /coach/chat': (_) => FakeResponse(
            200,
            sse([
              '{"type":"tool","name":"log_entry"}',
              '{"type":"logged","metric":"water"}',
              '{"type":"text","text":"Đã ghi "}',
              '{"type":"text","text":"500ml nước."}',
              '{"type":"done"}',
            ]),
          ),
        },
      );
      await openCoach(tester);
      expect(
        find.text('Hỏi mình về thói quen sức khỏe của bạn'),
        findsOneWidget,
      );

      final summaryBefore = app.backend.count('GET /stats/summary');
      await tester.enterText(find.byType(TextField), 'vừa uống 500ml');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pumpAndSettle();

      expect(find.text('vừa uống 500ml'), findsOneWidget);
      expect(find.text('Đã ghi 500ml nước.'), findsOneWidget);
      expect(find.text('Đã ghi nước uống'), findsOneWidget);
      final req = app.backend.requests.firstWhere(
        (r) => r.path == '/coach/chat',
      );
      final sent = (req.data as Map)['messages'] as List;
      expect(sent.single, {'role': 'user', 'content': 'vừa uống 500ml'});
      // Số liệu đã bị làm mới: đọc lại sẽ gọi máy chủ thay vì dùng bản cũ
      app.container.read(todaySummaryProvider);
      await tester.pumpAndSettle();
      expect(
        app.backend.count('GET /stats/summary'),
        greaterThan(summaryBefore),
      );
    },
  );

  testWidgets('chat: lỗi 503 hiện thông báo thay vì treo', (tester) async {
    await pumpApp(
      tester,
      overrides: {
        'POST /coach/chat': (_) => const FakeResponse(503, {
          'detail': 'AI Coach chưa được bật trên máy chủ',
        }),
      },
    );
    await openCoach(tester);
    await tester.tap(find.text('Vừa uống 500ml nước'));
    await tester.pumpAndSettle();
    expect(find.text('AI Coach chưa được bật trên máy chủ'), findsOneWidget);
  });
}
