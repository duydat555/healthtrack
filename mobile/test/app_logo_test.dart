import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/auth/auth_screens.dart';
import 'package:healthtrack/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo vẽ đúng cỡ và có nhãn đọc màn hình', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppLogo(size: 96))),
    );
    expect(tester.getSize(find.byType(AppLogo)), const Size(96, 96));
    expect(find.bySemanticsLabel('HealthTrack'), findsOneWidget);
  });

  testWidgets('SplashScreen hiện logo, đứng yên khi bật Giảm chuyển động', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AppLogo), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
