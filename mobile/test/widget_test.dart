import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/main.dart';

void main() {
  testWidgets('màn hình tạm hiển thị tên app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    expect(find.text('HealthTrack'), findsOneWidget);
  });
}
