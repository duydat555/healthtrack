import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/core_widgets.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/features/home/home_screen.dart';
import 'package:liquid_glass/liquid_glass.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets(
    'StatefulShellRoute giữ nguyên trạng thái cuộn của tab khi chuyển qua lại',
    (tester) async {
      await pumpApp(tester);

      final homeList = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(ListView),
      );
      await tester.drag(homeList, const Offset(0, -180));
      await tester.pumpAndSettle();

      final beforeOffset = Scrollable.of(
        tester.element(find.text('Hôm nay').first),
      ).position.pixels;
      expect(beforeOffset, greaterThan(0));

      await tester.tap(find.text('Mục tiêu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();

      final afterOffset = Scrollable.of(
        tester.element(find.text('Hôm nay').first),
      ).position.pixels;
      expect(afterOffset, equals(beforeOffset));
    },
  );

  testWidgets(
    'thanh tab dưới hiển thị không lỗi overflow trên iPhone SE (375x667) và iPhone Pro Max (430x932)',
    (tester) async {
      final sizes = <Size>[const Size(375, 667), const Size(430, 932)];
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;

      for (final size in sizes) {
        tester.view.physicalSize = size;
        await pumpApp(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidGlassTabBar), findsOneWidget);

        for (final label in const [
          'Chỉ số',
          'Mục tiêu',
          'Hồ sơ',
          'Tổng quan',
        ]) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'thanh tab có Semantics đầy đủ và errorBuilder hiện ErrorState khi route không tồn tại',
    (tester) async {
      final handle = tester.ensureSemantics();
      final app = await pumpApp(tester);

      for (final label in const ['Tổng quan', 'Chỉ số', 'Mục tiêu', 'Hồ sơ']) {
        expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
      }
      expect(find.bySemanticsLabel('Thêm nhanh'), findsOneWidget);

      app.container.read(routerProvider).go('/khong-ton-tai');
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);

      await tester.tap(find.text('Về trang chủ'));
      await tester.pumpAndSettle();
      expect(app.container.read(routerProvider).state.uri.path, '/');
      handle.dispose();
    },
  );
}
