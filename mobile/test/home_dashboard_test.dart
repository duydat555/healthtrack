import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/core_widgets.dart';
import 'package:liquid_glass/liquid_glass.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets(
    'Dashboard hiển thị đủ 5 nhóm chỉ số chính và dùng thẻ phẳng, không phủ Liquid Glass',
    (tester) async {
      await pumpApp(
        tester,
        overrides: {
          'GET /steps': (_) => const FakeResponse(200, [
            {'id': 1, 'steps': 7200, 'day': '2026-11-11'},
          ]),
          'GET /meals/total': (_) => const FakeResponse(200, {
            'date': '2026-11-11',
            'total_calories': 1850,
          }),
        },
      );

      // Thẻ nội dung là bề mặt phẳng, Liquid Glass chỉ dành cho lớp nổi (docs/05)
      expect(find.byType(LiquidGlass), findsNothing);
      expect(find.text('Bước chân'), findsOneWidget);
      expect(find.textContaining('7.200', findRichText: true), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
      expect(find.textContaining('1.850', findRichText: true), findsOneWidget);
      expect(find.text('Cân nặng'), findsOneWidget);
      expect(find.text('Giấc ngủ'), findsWidgets);
      expect(find.text('Nước uống'), findsWidgets);
    },
  );

  testWidgets('Pull-to-Refresh cập nhật lại dữ liệu Dashboard từ API', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final beforeSummary = app.backend.count('GET /stats/summary');
    final beforeWeights = app.backend.count('GET /weights');

    await tester.fling(find.byType(ListView), const Offset(0, 350), 1000);
    await tester.pumpAndSettle();

    expect(app.backend.count('GET /stats/summary'), greaterThan(beforeSummary));
    expect(app.backend.count('GET /weights'), greaterThan(beforeWeights));
  });

  testWidgets('hiển thị EmptyState khi chưa có dữ liệu sức khỏe nào', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: {
        'GET /weights': (_) => const FakeResponse(200, <Object>[]),
        'GET /sleep': (_) => const FakeResponse(200, <Object>[]),
        'GET /steps': (_) => const FakeResponse(200, <Object>[]),
        'GET /meals/total': (_) => const FakeResponse(200, {
          'date': '2026-11-11',
          'total_calories': 0,
        }),
        'GET /stats/trend': (_) =>
            const FakeResponse(200, {'metric': 'water', 'points': <Object>[]}),
      },
    );

    expect(find.byType(EmptyState), findsWidgets);
    expect(find.text('Ghi dữ liệu ngay'), findsOneWidget);
  });

  testWidgets('hiển thị ErrorState và Semantics, bấm Thử lại để khôi phục', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var fail = true;
    await pumpApp(
      tester,
      overrides: {
        'GET /weights': (_) => fail
            ? const FakeResponse(500, {'detail': 'Lỗi tải cân nặng'})
            : const FakeResponse(200, <Object>[]),
      },
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Hồ sơ của Người dùng Demo')),
      findsOneWidget,
    );

    fail = false;
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Cân nặng'), findsOneWidget);
    handle.dispose();
  });
}
