import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() {
  _moreTests();
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

const _items = [
  GlassTabItem(title: 'Tổng quan', symbol: 'house.fill', icon: Icons.home),
  GlassTabItem(title: 'Chỉ số', symbol: 'heart.fill', icon: Icons.favorite),
];

void _moreTests() {
  testWidgets('tab bar dự phòng: chạm tab gọi onTap, chạm nút nổi gọi onAdd', (
    tester,
  ) async {
    int? tapped;
    var added = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassTabBar(
            forceFallback: true,
            items: _items,
            currentIndex: 0,
            onTap: (i) => tapped = i,
            onAdd: () => added = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chỉ số'));
    expect(tapped, 1);
    await tester.tap(find.byIcon(Icons.add));
    expect(added, isTrue);
  });

  testWidgets('tab bar không có onAdd thì ẩn nút nổi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassTabBar(
            forceFallback: true,
            items: _items,
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('nhóm thẻ dự phòng: chạm thẻ mở rộng rồi chạm lại thu về', (
    tester,
  ) async {
    final events = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassCardGroup(
            forceFallback: true,
            height: 400,
            onExpandedChanged: events.add,
            cards: const [
              GlassCardData(
                id: 'a',
                title: 'Nước',
                subtitle: '1.2 L',
                detail: 'Chi tiết nước',
                symbol: 'drop.fill',
                icon: Icons.water_drop,
              ),
              GlassCardData(
                id: 'b',
                title: 'Ngủ',
                subtitle: '7 giờ',
                detail: 'Chi tiết ngủ',
                symbol: 'bed.double.fill',
                icon: Icons.bedtime,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Chi tiết nước'), findsNothing);
    await tester.tap(find.text('Nước'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết nước'), findsOneWidget);
    await tester.tap(find.text('Nước'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết nước'), findsNothing);
    expect(events, ['a', null]);
  });
}
