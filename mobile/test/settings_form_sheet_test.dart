import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/widgets/app_form.dart';
import 'package:healthtrack/widgets/form_sheet.dart';
import 'package:healthtrack/widgets/settings_group.dart';
import 'package:liquid_glass/liquid_glass.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: SafeArea(child: child)),
);

void main() {
  testWidgets('SettingsRow: giá trị nằm sát mép phải của hàng', (tester) async {
    await tester.pumpWidget(
      _host(
        SettingsGroup(
          children: [
            SettingsRow(
              title: 'Họ và tên',
              value: 'Đạt',
              icon: Icons.person,
              onTap: () {},
            ),
            SettingsRow(
              title: 'Nhắc nhở',
              subtitle: 'Uống nước, uống thuốc, đi ngủ',
              value: 'Cài đặt',
              icon: Icons.notifications,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    final rowRight = tester.getTopRight(find.byType(SettingsGroup)).dx;
    for (final v in ['Đạt', 'Cài đặt']) {
      final gap = rowRight - tester.getTopRight(find.text(v)).dx;
      // Chỉ còn chevron (15) + khoảng đệm; lệch giữa hàng sẽ vượt xa ngưỡng này
      expect(gap, lessThan(50), reason: 'Giá trị "$v" bị lệch khỏi mép phải');
    }
  });

  testWidgets('SettingsRow: giá trị, mũi tên, công tắc và hàng nguy hiểm', (
    tester,
  ) async {
    var tapped = 0;
    var toggled = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SettingsGroup(
            title: 'Thông tin',
            footer: 'Chỉ bạn thấy dữ liệu này.',
            children: [
              SettingsRow(
                title: 'Tên',
                value: 'Đạt',
                icon: Icons.person,
                onTap: () => tapped++,
              ),
              SettingsRow.toggle(
                title: 'Riêng tư',
                value: toggled,
                onChanged: (v) => setState(() => toggled = v),
              ),
              SettingsRow(title: 'Đăng xuất', destructive: true, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Chỉ bạn thấy dữ liệu này.'), findsOneWidget);
    expect(find.text('Đạt'), findsOneWidget);

    await tester.tap(find.text('Tên'));
    expect(tapped, 1);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(toggled, isTrue);

    // Hàng nguy hiểm dùng màu danger, hàng thường dùng ink
    final logout = tester.widget<Text>(find.text('Đăng xuất'));
    expect(logout.style!.color, AppColorPalette.light.danger);
    final name = tester.widget<Text>(find.text('Tên'));
    expect(name.style!.color, AppColorPalette.light.ink);

    // Hàng cao tối thiểu 44 để dễ chạm
    for (final row in find.byType(SettingsRow).evaluate()) {
      expect(
        tester.getSize(find.byWidget(row.widget)).height,
        greaterThanOrEqualTo(44),
      );
    }
    expect(tester.takeException(), isNull);
  });

  group('showFormSheet', () {
    late TextEditingController text;
    var saved = 0;

    setUp(() {
      text = TextEditingController();
      saved = 0;
    });
    tearDown(() => text.dispose());

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showFormSheet(
                context: context,
                title: 'Mục tiêu nước',
                onSave: () async {
                  saved++;
                  return true;
                },
                builder: (context, form) => AppTextField(
                  controller: text,
                  label: 'Lượng nước',
                  suffixText: 'lít',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => form.update(
                    dirty: v.isNotEmpty,
                    valid: (double.tryParse(v) ?? 0) > 0,
                  ),
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
    }

    testWidgets('nút Lưu tắt đến khi dữ liệu hợp lệ rồi lưu và đóng', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Mục tiêu nước'), findsOneWidget);
      expect(find.text('lít'), findsOneWidget);

      GlassButton saveButton() =>
          tester.widget<GlassButton>(find.widgetWithText(GlassButton, 'Lưu'));
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), '2.5');
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);

      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.text('Mục tiêu nước'), findsNothing);
    });

    testWidgets('chưa sửa thì Hủy đóng ngay, không hỏi', (tester) async {
      await open(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu nước'), findsNothing);
      expect(find.text('Bỏ thay đổi?'), findsNothing);
    });

    testWidgets('đã sửa mà bấm Hủy thì hỏi, có thể tiếp tục sửa hoặc bỏ', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), '1');
      await tester.pump();

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);

      // Tiếp tục sửa: sheet còn, dữ liệu còn
      await tester.tap(find.text('Tiếp tục sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu nước'), findsOneWidget);
      expect(text.text, '1');

      // Bỏ thay đổi: sheet đóng, không lưu
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Mục tiêu nước'), findsNothing);
      expect(saved, 0);
    });
  });
}
