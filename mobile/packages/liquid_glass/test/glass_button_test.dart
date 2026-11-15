import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('GlassButton.prominent: bấm được, có nhãn đọc màn hình', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GlassButton.prominent(
          label: 'Đăng nhập',
          onPressed: () => taps++,
          tint: Colors.amber,
          onTint: Colors.black,
          forceFallback: true,
        ),
      ),
    );
    await tester.tap(find.text('Đăng nhập'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Đăng nhập'), findsOneWidget);
  });

  testWidgets('GlassButton: tắt khi đang tải hoặc onPressed null', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GlassButton.prominent(
          label: 'Lưu',
          onPressed: () => taps++,
          tint: Colors.amber,
          onTint: Colors.black,
          loading: true,
          forceFallback: true,
        ),
      ),
    );
    await tester.tap(find.byType(GlassButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.text('Lưu'), findsNothing);
  });

  testWidgets('GlassIconButton: bấm được và hiện icon dự phòng', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GlassIconButton(
          symbol: 'chevron.left',
          fallbackIcon: Icons.arrow_back,
          semanticLabel: 'Quay lại',
          foreground: Colors.white,
          forceFallback: true,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Quay lại'), findsOneWidget);
  });
}
