import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/widgets/core_widgets.dart';
import 'package:healthtrack/widgets/skeletons.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('khung đặt chỗ có nhãn đọc màn hình và không tràn ở màn nhỏ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            RingsCardSkeleton(),
            MetricGridSkeleton(),
            MetricListSkeleton(count: 2),
            ProfileSkeleton(),
            GoalListSkeleton(),
            BadgeGridSkeleton(),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Đang tải tóm tắt hôm nay'), findsOneWidget);
    expect(find.bySemanticsLabel('Đang tải hồ sơ'), findsOneWidget);
  });

  testWidgets('skeleton đứng yên khi bật Giảm chuyển động, thở nhẹ khi không', (
    tester,
  ) async {
    double opacity() => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(SkeletonGroup),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    await tester.pumpWidget(
      _host(const SkeletonGroup(child: SkeletonBlock()), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(opacity(), 1);

    await tester.pumpWidget(_host(const SkeletonGroup(child: SkeletonBlock())));
    await tester.pump(const Duration(milliseconds: 700));
    expect(opacity(), lessThan(1));
  });

  testWidgets(
    'AppActivityIndicator: kim quay trên iOS, vòng Material nơi khác',
    (tester) async {
      await tester.pumpWidget(_host(const AppActivityIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_host(const AppActivityIndicator()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
