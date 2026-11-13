import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets(
    'thêm thuốc bằng form sheet: tên bắt buộc, lưu gửi đúng dữ liệu',
    (tester) async {
      final app = await pumpApp(
        tester,
        overrides: {
          'POST /medications': (_) => const FakeResponse(201, {
            'id': 8,
            'name': 'Vitamin C',
            'dosage': '500 mg',
            'is_active': true,
          }),
        },
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thuốc'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Thêm thuốc'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm thuốc'));
      await tester.pumpAndSettle();

      // Form sheet: Lưu ("Thêm") tắt khi chưa nhập tên
      TextButton add() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Thêm'));
      expect(add().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).at(0), 'Vitamin C');
      await tester.enterText(find.byType(TextFormField).at(1), '500 mg');
      await tester.pump();
      expect(add().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(TextButton, 'Thêm'));
      await tester.pumpAndSettle();

      final post = app.backend.requests.firstWhere(
        (r) => r.method == 'POST' && r.path == '/medications',
      );
      expect((post.data as Map)['name'], 'Vitamin C');
      expect((post.data as Map)['dosage'], '500 mg');
    },
  );
}
