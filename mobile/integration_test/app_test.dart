import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// Chạy trên Simulator: cd mobile && flutter test integration_test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app khởi động và hiện màn hình chính', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle();
    expect(find.text('HealthTrack'), findsOneWidget);
  });
}
