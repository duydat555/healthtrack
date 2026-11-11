import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

Future<void> _openReminders(WidgetTester tester) async {
  await tester.tap(find.text('Hồ sơ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nhắc nhở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'hiển thị trạng thái rỗng khi chưa có nhắc nhở và Semantics chuẩn',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        overrides: {
          'GET /reminders': (_) => const FakeResponse(200, <Object>[]),
        },
      );
      await _openReminders(tester);

      expect(find.text('Chưa có nhắc nhở nào'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Thêm nhắc nhở đầu tiên')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Thêm nhắc nhở mới'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('hiển thị trạng thái lỗi và tải lại khi bấm Thử lại', (
    tester,
  ) async {
    var shouldFail = true;
    await pumpApp(
      tester,
      overrides: {
        'GET /reminders': (_) {
          if (shouldFail) {
            return const FakeResponse(500, {'detail': 'Lỗi máy chủ'});
          }
          return const FakeResponse(200, [
            {'id': 1, 'kind': 'water', 'at_time': '08:30:00', 'enabled': true},
          ]);
        },
      },
    );
    await _openReminders(tester);
    expect(find.text('Thử lại'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Uống nước · Đang bật'), findsOneWidget);
  });

  testWidgets(
    'tạo nhắc nhở mới dùng CupertinoDatePicker và gọi POST /reminders',
    (tester) async {
      final rows = <Map<String, Object?>>[];
      final app = await pumpApp(
        tester,
        overrides: {
          'GET /reminders': (_) => FakeResponse(200, rows),
          'POST /reminders': (req) {
            final body = (req.data as Map).cast<String, Object?>();
            final created = <String, Object?>{
              'id': 10,
              'kind': body['kind'],
              'at_time': body['at_time'],
              'enabled': body['enabled'],
            };
            rows.add(created);
            return FakeResponse(201, created);
          },
        },
      );
      await _openReminders(tester);
      await tester.tap(find.byTooltip('Thêm nhắc nhở'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Uống thuốc'));
      await tester.pumpAndSettle();

      final saveBtn = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, 'Thêm nhắc nhở'),
      );
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final post = app.backend.requests.firstWhere(
        (r) => r.method == 'POST' && r.path == '/reminders',
      );
      expect((post.data as Map)['kind'], 'medication');
      expect((post.data as Map)['at_time'], '08:00:00');
      expect((post.data as Map)['enabled'], true);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Uống thuốc · Đang bật'), findsOneWidget);
    },
  );

  testWidgets(
    'bật/tắt và xóa nhắc nhở đồng bộ với PATCH và DELETE /reminders',
    (tester) async {
      final rows = <Map<String, Object?>>[
        {'id': 5, 'kind': 'sleep', 'at_time': '22:30:00', 'enabled': true},
      ];
      final app = await pumpApp(
        tester,
        overrides: {
          'GET /reminders': (_) => FakeResponse(200, rows),
          'PATCH /reminders/5': (req) {
            final body = (req.data as Map).cast<String, Object?>();
            rows[0] = {...rows[0], ...body};
            return FakeResponse(200, rows[0]);
          },
          'DELETE /reminders/5': (_) {
            rows.clear();
            return const FakeResponse(204);
          },
        },
      );
      await _openReminders(tester);
      expect(find.text('22:30'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final patch = app.backend.requests.firstWhere(
        (r) => r.method == 'PATCH' && r.path == '/reminders/5',
      );
      expect((patch.data as Map)['enabled'], false);
      expect(find.text('Đi ngủ · Đang tắt'), findsOneWidget);

      await tester.tap(find.text('22:30'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa nhắc nhở'), findsOneWidget);

      final deleteBtn = find.text('Xóa nhắc nhở');
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(app.backend.count('DELETE /reminders/5'), 1);
      expect(find.text('Chưa có nhắc nhở nào'), findsOneWidget);
    },
  );
}
