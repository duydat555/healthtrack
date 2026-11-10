import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

Future<({FakeBackend backend, dynamic container})> _openAdd(
  WidgetTester tester,
  String kind,
  Map<String, FakeHandler> overrides,
) async {
  final app = await pumpApp(tester, overrides: overrides);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, kind));
  await tester.pumpAndSettle();
  return (backend: app.backend, container: app.container);
}

String _today() {
  final date = DateTime.now();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('form bước chân từ chối đầu vào không hợp lệ', (tester) async {
    final app = await _openAdd(tester, 'Bước chân', {
      'GET /steps': (_) => const FakeResponse(200, <Object>[]),
    });
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu bước chân'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số bước.'), findsOneWidget);
    expect(app.backend.count('POST /steps'), 0);

    await tester.enterText(find.byType(TextFormField), '-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu bước chân'));
    await tester.pumpAndSettle();
    expect(find.text('Số bước phải là số nguyên không âm.'), findsOneWidget);
    expect(app.backend.count('POST /steps'), 0);
  });

  testWidgets('lưu bước chân và tải lại danh sách', (tester) async {
    final rows = <Map<String, Object?>>[];
    final app = await _openAdd(tester, 'Bước chân', {
      'GET /steps': (_) => FakeResponse(200, rows),
      'POST /steps': (request) {
        final payload = (request.data as Map).cast<String, Object?>();
        final row = <String, Object?>{
          'id': 1,
          ...payload,
          'created_at': '2026-11-10T00:00:00Z',
        };
        rows
          ..clear()
          ..add(row);
        return FakeResponse(201, row);
      },
    });

    await tester.enterText(find.byType(TextFormField), '8500');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu bước chân'));
    await tester.pumpAndSettle();

    final request = app.backend.requests.firstWhere(
      (item) => item.method == 'POST' && item.path == '/steps',
    );
    expect((request.data as Map)['steps'], 8500);
    expect((request.data as Map)['day'], _today());
    expect(find.text('8.500 bước'), findsOneWidget);
    expect(app.backend.count('GET /steps'), greaterThan(1));
  });

  testWidgets('form bữa ăn validate tên món và calories', (tester) async {
    final app = await _openAdd(tester, 'Bữa ăn', {
      'GET /meals': (_) => const FakeResponse(200, <Object>[]),
      'GET /meals/total': (_) =>
          const FakeResponse(200, {'date': '2026-11-10', 'total_calories': 0}),
    });
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu bữa ăn'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên món ăn.'), findsOneWidget);
    expect(find.text('Nhập calories.'), findsOneWidget);
    expect(app.backend.count('POST /meals'), 0);
  });

  testWidgets('lưu bữa ăn và cập nhật tổng cùng danh sách', (tester) async {
    final rows = <Map<String, Object?>>[];
    var total = 0;
    final app = await _openAdd(tester, 'Bữa ăn', {
      'GET /meals': (_) => FakeResponse(200, rows),
      'GET /meals/total': (_) =>
          FakeResponse(200, {'date': _today(), 'total_calories': total}),
      'POST /meals': (request) {
        final payload = (request.data as Map).cast<String, Object?>();
        total += payload['calories']! as int;
        final row = <String, Object?>{
          'id': 1,
          ...payload,
          'logged_at': '2026-11-10T12:00:00Z',
          'created_at': '2026-11-10T12:00:00Z',
        };
        rows.add(row);
        return FakeResponse(201, row);
      },
    });

    await tester.enterText(find.byType(TextFormField).at(0), 'Cơm gà');
    await tester.enterText(find.byType(TextFormField).at(1), '650');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu bữa ăn'));
    await tester.pumpAndSettle();

    final request = app.backend.requests.firstWhere(
      (item) => item.method == 'POST' && item.path == '/meals',
    );
    expect((request.data as Map)['meal_type'], 'breakfast');
    expect((request.data as Map)['name'], 'Cơm gà');
    expect((request.data as Map)['calories'], 650);
    expect(find.text('Cơm gà'), findsOneWidget);
    expect(find.text('Tổng hôm nay: 650 kcal'), findsOneWidget);
    expect(app.backend.count('GET /meals'), greaterThan(1));
    expect(app.backend.count('GET /meals/total'), greaterThan(1));
  });
}
