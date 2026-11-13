import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/core_widgets.dart';

import 'helpers/fake_backend.dart';

Future<({FakeBackend backend, dynamic container})> _openAdd(
  WidgetTester tester, {
  Map<String, FakeHandler> overrides = const {},
}) async {
  final app = await pumpApp(tester, overrides: overrides);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  return (backend: app.backend, container: app.container);
}

void main() {
  testWidgets(
    'nước uống từ chối chữ không hợp lệ, hiển thị ErrorState/EmptyState và xóa được bản ghi',
    (tester) async {
      var failWater = true;
      final rows = <Map<String, Object?>>[
        {'id': 1, 'amount_ml': 330, 'logged_at': '2026-11-11T08:00:00Z'},
      ];
      final app = await _openAdd(
        tester,
        overrides: {
          'GET /water': (_) {
            if (failWater) {
              return const FakeResponse(500, {'detail': 'Lỗi tải nước'});
            }
            return FakeResponse(200, rows);
          },
          'DELETE /water/1': (_) {
            rows.clear();
            return const FakeResponse(204);
          },
        },
      );

      // Validation từ chối chữ không phải số
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm nước'));
      await tester.pumpAndSettle();
      expect(find.text('Lượng nước phải từ 1 đến 5.000 ml.'), findsOneWidget);
      expect(app.backend.count('POST /water'), 0);

      // ErrorState có nút Thử lại
      expect(find.byType(ErrorState), findsOneWidget);
      failWater = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('330 ml'), findsWidgets);

      // Xóa bản ghi nước uống -> cập nhật về EmptyState
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(app.backend.count('DELETE /water/1'), 1);
      expect(find.byType(EmptyState), findsOneWidget);
    },
  );

  testWidgets(
    'ghi cân nặng tính trước BMI, gọi POST /weights, hiện kết quả BMI và làm mới danh sách',
    (tester) async {
      final rows = <Map<String, Object?>>[];
      final app = await _openAdd(
        tester,
        overrides: {
          'GET /weights': (_) => FakeResponse(200, rows),
          'POST /weights': (req) {
            final kg = ((req.data as Map)['weight_kg'] as num).toDouble();
            final row = <String, Object?>{
              'id': 99,
              'weight_kg': kg,
              'bmi': 23.5,
              'logged_at': '2026-11-11T09:00:00Z',
            };
            rows
              ..clear()
              ..add(row);
            return FakeResponse(201, row);
          },
        },
      );

      await tester.tap(find.text('Cân nặng').last);
      await tester.pumpAndSettle();

      // demoUser có height_cm = 170 -> 68 kg => BMI = 23.5 (Bình thường)
      await tester.enterText(find.byType(TextFormField), '68');
      await tester.pump();
      expect(find.text('BMI dự kiến'), findsOneWidget);
      expect(find.text('BMI 23,5 · Bình thường'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Ghi cân nặng'));
      await tester.pumpAndSettle();

      expect(app.backend.count('POST /weights'), 1);
      expect(app.backend.count('GET /weights'), greaterThan(1));
      expect(find.text('Chỉ số BMI vừa ghi nhận'), findsOneWidget);
      expect(find.text('68 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'ghi giấc ngủ hiển thị thời lượng dự kiến, lưu POST /sleep, cập nhật danh sách và Semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      final rows = <Map<String, Object?>>[];
      final app = await _openAdd(
        tester,
        overrides: {
          'GET /sleep': (_) => FakeResponse(200, rows),
          'POST /sleep': (req) {
            final row = <String, Object?>{
              'id': 12,
              'start_at': '2026-11-10T16:00:00Z',
              'end_at': '2026-11-11T00:00:00Z',
              'quality': (req.data as Map)['quality'],
              'duration_minutes': 480,
            };
            rows.add(row);
            return FakeResponse(201, row);
          },
        },
      );

      await tester.tap(find.text('Ngủ'));
      await tester.pumpAndSettle();

      expect(find.text('Thời lượng dự kiến: 8 giờ'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Thời lượng ngủ dự kiến 8 giờ')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('4 sao'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Ghi giấc ngủ'));
      await tester.pumpAndSettle();

      expect(app.backend.count('POST /sleep'), 1);
      expect(app.backend.count('GET /sleep'), greaterThan(1));
      expect(find.text('8 giờ'), findsOneWidget);
      handle.dispose();
    },
  );
}
