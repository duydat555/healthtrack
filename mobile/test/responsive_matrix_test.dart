import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';

import 'helpers/fake_backend.dart';

/// Các màn chính phải dựng được, không tràn (overflow) ở mọi cỡ màn hình, cỡ chữ và chế độ sáng/tối.
void main() {
  const sizes = {
    'iPhone nhỏ 320x568': Size(320, 568),
    'iPhone SE 375x667': Size(375, 667),
    'iPhone 13 390x844': Size(390, 844),
    'iPhone Pro Max 430x932': Size(430, 932),
  };
  const routes = ['/', '/metrics', '/goals', '/profile', '/add'];

  for (final entry in sizes.entries) {
    for (final scale in const [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${entry.key}, chữ ${scale}x, ${brightness.name}: không overflow',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = entry.value;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;

            final app = await pumpApp(tester);
            for (final route in routes) {
              app.container.read(routerProvider).go(route);
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '$route ở ${entry.key}, chữ ${scale}x, ${brightness.name}',
              );
            }
          },
        );
      }
    }
  }
}
