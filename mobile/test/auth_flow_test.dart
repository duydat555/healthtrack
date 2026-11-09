import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/features/home/home_screen.dart';

import 'helpers/fake_backend.dart';

void main() {
  testWidgets('chưa đăng nhập thì bị chuyển tới màn đăng nhập', (tester) async {
    final app = await pumpApp(tester, loggedIn: false);
    expect(app.container.read(routerProvider).state.uri.path, '/login');
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.byType(HomeScreen), findsNothing);
    // không gọi API dữ liệu khi chưa có phiên
    expect(app.backend.count('GET /users/me'), 0);
  });

  testWidgets('đăng nhập đúng: lưu token và vào màn Tổng quan', (tester) async {
    final app = await pumpApp(tester, loggedIn: false);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@healthtrack.example',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect((await app.storage.read())?.access, 'access-1');
    expect(app.container.read(routerProvider).state.uri.path, '/');
  });

  testWidgets(
    'đăng nhập sai: hiện thông báo của máy chủ và ở lại màn đăng nhập',
    (tester) async {
      final app = await pumpApp(tester, loggedIn: false);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'demo@healthtrack.example',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'sai-mat-khau');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(await app.storage.read(), isNull);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets('kiểm tra form: email sai định dạng và mật khẩu rỗng', (
    tester,
  ) async {
    final app = await pumpApp(tester, loggedIn: false);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'khong-phai-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Email chưa đúng định dạng'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
    expect(app.backend.count('POST /auth/login'), 0);
  });

  testWidgets('đăng ký: gọi register rồi đăng nhập luôn', (tester) async {
    final app = await pumpApp(tester, loggedIn: false);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(app.container.read(routerProvider).state.uri.path, '/register');

    await tester.enterText(find.byType(TextFormField).at(0), 'Demo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'demo@healthtrack.example',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(app.backend.count('POST /auth/register'), 1);
    expect(app.backend.count('POST /auth/login'), 1);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('đăng ký trùng email: hiện lỗi 409 của máy chủ', (tester) async {
    await pumpApp(
      tester,
      loggedIn: false,
      overrides: {
        'POST /auth/register': (_) =>
            const FakeResponse(409, {'detail': 'Email đã được đăng ký'}),
      },
    );
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Demo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'demo@healthtrack.example',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Email đã được đăng ký'), findsOneWidget);
  });

  testWidgets('đăng xuất xóa token và về màn đăng nhập', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(await app.storage.read(), isNull);
    expect(app.container.read(routerProvider).state.uri.path, '/login');
  });

  testWidgets('mở app với token đã hết hạn hẳn thì về đăng nhập và xóa token', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      overrides: {
        'GET /users/me': (_) => const FakeResponse(401, {'detail': 'hết hạn'}),
        'POST /auth/refresh': (_) =>
            const FakeResponse(401, {'detail': 'hết hạn'}),
      },
    );
    expect(app.container.read(routerProvider).state.uri.path, '/login');
    expect(await app.storage.read(), isNull);
  });
}
