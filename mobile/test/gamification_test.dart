import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('Tổng quan hiện Health Score, chuỗi ngày và thử thách tuần', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Điểm sức khỏe'), findsOneWidget);
    expect(find.text('3 ngày liền'), findsOneWidget);
    expect(find.text('Uống đủ nước 5 ngày trong tuần'), findsOneWidget);
  });

  testWidgets('màn Huy hiệu: huy hiệu đã đạt và chưa đạt có nhãn Semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    router.push('/achievements');
    await tester.pumpAndSettle();
    expect(find.text('Đã đạt 1 trên 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Bước đầu tiên.*Đã đạt')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Một tuần bền bỉ.*Chưa đạt')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
