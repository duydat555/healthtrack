import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/main.dart';
import 'package:healthtrack/widgets/activity_rings.dart';

void main() {
  testWidgets('màn Tổng quan hiển thị vòng Activity Rings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.byType(ActivityRings), findsOneWidget);
  });
}
