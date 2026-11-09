import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';

import 'helpers/fake_backend.dart';

Future<({FakeBackend backend, dynamic container})> _openAdd(
  WidgetTester tester,
) async {
  final app = await pumpApp(tester);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  return (backend: app.backend, container: app.container);
}

void main() {
  testWidgets('thêm nước: gửi đúng lượng ml, đóng màn và tải lại dữ liệu', (
    tester,
  ) async {
    final app = await _openAdd(tester);
    await tester.tap(find.text('330 ml'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
    await tester.pumpAndSettle();

    final post = app.backend.requests.firstWhere(
      (r) => r.method == 'POST' && r.path == '/water',
    );
    expect((post.data as Map)['amount_ml'], 330);
    expect(app.container.read(routerProvider).state.uri.path, '/');
    // dữ liệu Tổng quan được tải lại sau khi ghi
    expect(app.backend.count('GET /stats/summary'), greaterThan(1));
  });

  testWidgets('nhập số ml tùy ý ưu tiên hơn nút chọn sẵn', (tester) async {
    final app = await _openAdd(tester);
    await tester.enterText(find.byType(TextFormField), '400');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
    await tester.pumpAndSettle();
    final post = app.backend.requests.firstWhere(
      (r) => r.method == 'POST' && r.path == '/water',
    );
    expect((post.data as Map)['amount_ml'], 400);
  });

  testWidgets('lượng nước quá lớn bị từ chối ngay, không gọi API', (
    tester,
  ) async {
    final app = await _openAdd(tester);
    await tester.enterText(find.byType(TextFormField), '9000');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
    await tester.pumpAndSettle();
    expect(find.textContaining('từ 1 đến 5.000 ml'), findsOneWidget);
    expect(app.backend.count('POST /water'), 0);
  });

  testWidgets('ghi cân nặng chấp nhận dấu phẩy thập phân', (tester) async {
    final app = await _openAdd(tester);
    await tester.tap(find.text('Cân nặng').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '67,5');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi cân nặng'));
    await tester.pumpAndSettle();
    final post = app.backend.requests.firstWhere(
      (r) => r.method == 'POST' && r.path == '/weights',
    );
    expect((post.data as Map)['weight_kg'], 67.5);
  });

  testWidgets('cân nặng không hợp lệ bị từ chối', (tester) async {
    final app = await _openAdd(tester);
    await tester.tap(find.text('Cân nặng').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi cân nặng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('từ 1 đến 500 kg'), findsOneWidget);
    expect(app.backend.count('POST /weights'), 0);
  });

  testWidgets('lỗi từ máy chủ được hiện ra và màn không đóng', (tester) async {
    final app = await pumpApp(
      tester,
      overrides: {
        'POST /water': (_) =>
            const FakeResponse(422, {'detail': 'Lượng nước không hợp lệ'}),
      },
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
    await tester.pumpAndSettle();
    expect(find.text('Lượng nước không hợp lệ'), findsOneWidget);
    expect(app.container.read(routerProvider).state.uri.path, '/add');
  });
}
