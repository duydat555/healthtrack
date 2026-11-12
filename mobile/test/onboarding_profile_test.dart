import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/features/home/home_screen.dart';
import 'package:healthtrack/features/onboarding/onboarding_screen.dart';
import 'package:healthtrack/features/profile/profile_state_widgets.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets(
    'người dùng chưa có chiều cao đi qua 3 bước Onboarding lưu chiều cao, cân nặng và tính BMI',
    (tester) async {
      final user = Map<String, Object?>.from(demoUser)..['height_cm'] = null;
      final app = await pumpApp(
        tester,
        overrides: {'GET /users/me': (_) => FakeResponse(200, user)},
      );

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Chào mừng đến với HealthTrack'), findsOneWidget);

      // Bước 1 -> Bước 2
      await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin cá nhân'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Nguyễn An');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nữ'));
      await tester.pumpAndSettle();

      // Bước 2 -> Bước 3
      await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉ số ban đầu'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '165');
      await tester.enterText(find.byType(TextFormField).at(1), '55');
      await tester.pump();
      expect(find.textContaining('BMI ban đầu: 20,2'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Hoàn tất'));
      await tester.pumpAndSettle();

      final patch = app.backend.requests.firstWhere(
        (r) => r.method == 'PATCH' && r.path == '/users/me',
      );
      expect((patch.data as Map)['full_name'], 'Nguyễn An');
      expect((patch.data as Map)['gender'], 'female');
      expect((patch.data as Map)['height_cm'], 165.0);

      final weightPost = app.backend.requests.firstWhere(
        (r) => r.method == 'POST' && r.path == '/weights',
      );
      expect((weightPost.data as Map)['weight_kg'], 55.0);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('bấm Bỏ qua ở Onboarding đưa người dùng vào Trang chủ', (
    tester,
  ) async {
    final user = Map<String, Object?>.from(demoUser)..['height_cm'] = null;
    await pumpApp(
      tester,
      overrides: {'GET /users/me': (_) => FakeResponse(200, user)},
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'ProfileScreen chỉnh sửa họ tên, giới tính, chiều cao qua /users/me và có Semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      var currentUser = Map<String, Object?>.from(demoUser);
      final app = await pumpApp(
        tester,
        overrides: {
          'GET /users/me': (_) => FakeResponse(200, currentUser),
          'PATCH /users/me': (req) {
            currentUser = {
              ...currentUser,
              ...(req.data as Map).cast<String, Object?>(),
            };
            return FakeResponse(200, currentUser);
          },
        },
      );

      app.container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Mở thiết lập ban đầu Onboarding')),
        findsOneWidget,
      );

      // Sửa họ và tên
      await tester.tap(find.text('Họ và tên'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Trần Bình');
      await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Trần Bình'), findsWidgets);

      // Sửa giới tính
      await tester.tap(find.text('Giới tính'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nam'));
      await tester.pumpAndSettle();
      expect(find.text('Nam'), findsOneWidget);

      // Sửa chiều cao
      await tester.tap(find.text('Chiều cao'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '175');
      await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('175 cm'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('Profile ErrorState hiển thị thông báo và gọi callback Thử lại', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            message: 'Lỗi tải hồ sơ',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Lỗi tải hồ sơ'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });
}
