import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() {
  testWidgets('không có Swift thì dùng BackdropFilter làm bản dự phòng', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiquidGlass(child: Text('kính'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.text('kính'), findsOneWidget);
  });

  test('supportsLiquidGlass trả false ngoài iOS', () async {
    expect(await supportsLiquidGlass(), isFalse);
  });
}
