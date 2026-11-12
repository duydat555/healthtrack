import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/state_widgets.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('ErrorState hiển thị thông báo và gọi callback khi bấm Thử lại', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            message: 'Mất kết nối máy chủ',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Mất kết nối máy chủ'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Thử lại tải dữ liệu')),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
    handle.dispose();
  });

  testWidgets('EmptyState hiển thị thông điệp và nút hành động', (
    tester,
  ) async {
    var acted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            message: 'Chưa có dữ liệu',
            actionLabel: 'Thêm ngay',
            onAction: () => acted = true,
          ),
        ),
      ),
    );
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    await tester.tap(find.text('Thêm ngay'));
    expect(acted, isTrue);
  });

  testWidgets('MetricsScreen hiển thị EmptyState khi chưa có dữ liệu', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: {
        'GET /weights': (_) => const FakeResponse(200, <Object>[]),
        'GET /sleep': (_) => const FakeResponse(200, <Object>[]),
        'GET /stats/trend': (_) =>
            const FakeResponse(200, {'metric': 'water', 'points': <Object>[]}),
      },
    );
    await tester.tap(find.text('Chỉ số'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Ghi dữ liệu ngay'), findsOneWidget);
  });

  testWidgets(
    'GoalsScreen hiển thị EmptyState và Semantics khi chưa đặt mục tiêu',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        overrides: {'GET /goals': (_) => const FakeResponse(200, <Object>[])},
      );
      await tester.tap(find.text('Mục tiêu'));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Mục tiêu').first).label,
        contains('Mục tiêu'),
      );
      handle.dispose();
    },
  );

  testWidgets('ProfileScreen có Semantics cho các nút chính', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Đăng xuất khỏi tài khoản'), findsOneWidget);
    handle.dispose();
  });
}
