import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/widgets/activity_rings.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('màn Tổng quan hiện vòng Activity Rings với dữ liệu từ API', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Hôm nay'), findsWidgets);
    expect(find.byType(ActivityRings), findsOneWidget);
    // 500 + 300 ml nước hôm nay, mục tiêu mặc định 2 lít
    expect(find.textContaining('0,8', findRichText: true), findsWidgets);
    expect(find.textContaining('/2 LÍT', findRichText: true), findsOneWidget);
    // giấc ngủ 480 phút = 8 giờ
    expect(find.textContaining('/8 GIỜ', findRichText: true), findsOneWidget);
    // chữ cái đầu của "Người dùng Demo"
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('API lỗi mạng thì hiện thông báo và nút thử lại', (tester) async {
    await pumpApp(
      tester,
      overrides: {'GET /water': (_) => throw StateError('mất mạng')},
    );
    expect(find.text('Thử lại'), findsWidgets);
  });
}
