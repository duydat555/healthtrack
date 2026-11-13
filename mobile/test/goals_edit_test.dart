import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets(
    'sửa mục tiêu: kiểm tra khoảng hợp lệ, lưu lên máy chủ và đóng sheet',
    (tester) async {
      final app = await pumpApp(
        tester,
        overrides: {
          'POST /goals': (_) => const FakeResponse(201, {
            'id': 1,
            'metric': 'water',
            'period': 'daily',
            'target_value': 3000,
            'unit': 'ml',
            'created_at': '2026-11-09T00:00:00Z',
            'updated_at': '2026-11-09T00:00:00Z',
          }),
        },
      );
      await tester.tap(find.text('Mục tiêu'));
      await tester.pumpAndSettle();

      // Chưa có mục tiêu: hiện trạng thái rỗng có nút hành động và các thẻ có nút Đặt
      expect(find.text('Đặt mục tiêu'), findsOneWidget);
      await tester.tap(find.text('Nước uống'));
      await tester.pumpAndSettle();

      // Sheet: tiêu đề, đơn vị, và Lưu mở sẵn vì giá trị mặc định (2) hợp lệ
      expect(find.text('Mục tiêu nước uống'), findsOneWidget);
      expect(find.text('lít/ngày'), findsOneWidget);
      TextButton save() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Lưu'));
      expect(save().onPressed, isNotNull);

      // Ngoài khoảng: báo lỗi và tắt Lưu
      await tester.enterText(find.byType(TextFormField), '25');
      await tester.pump();
      expect(find.text('Tối đa 20 lít/ngày'), findsWidgets);
      expect(save().onPressed, isNull);

      // Không phải số
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();
      expect(find.text('Nhập số lớn hơn 0'), findsOneWidget);
      expect(save().onPressed, isNull);

      // Hợp lệ: lưu và đóng
      await tester.enterText(find.byType(TextFormField), '3');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(app.backend.count('POST /goals'), 1);
      final body =
          app.backend.requests
                  .firstWhere((r) => r.method == 'POST' && r.path == '/goals')
                  .data
              as Map;
      expect(body['metric'], 'water');
      expect(body['target_value'], 3000);
      expect(find.text('Mục tiêu nước uống'), findsNothing);
      expect(find.text('Đã lưu mục tiêu nước uống'), findsOneWidget);
    },
  );

  testWidgets('sửa mục tiêu: đã nhập mà bấm Hủy thì hỏi trước khi bỏ', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Mục tiêu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giấc ngủ'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '7');
    await tester.pump();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu giấc ngủ'), findsNothing);
  });
}
