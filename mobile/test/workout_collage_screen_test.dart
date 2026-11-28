import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/workout/collage/workout_collage_media.dart';
import 'package:healthtrack/features/workout/collage/workout_collage_painter.dart';
import 'package:healthtrack/features/workout/collage/workout_collage_screen.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers/fake_backend.dart';
import 'helpers/workout_collage_fixture.dart';

const _preview = ValueKey('collage-preview');

class _Media extends WorkoutCollageMedia {
  _Media({this.photo});

  final ui.Image? photo;
  final sources = <ImageSource>[];
  final saved = Completer<Uint8List>();
  final shared = Completer<Uint8List>();
  Rect? shareOrigin;

  @override
  Future<ui.Image?> pickPhoto(ImageSource source) async {
    sources.add(source);
    return source == ImageSource.gallery ? photo : null;
  }

  @override
  Future<void> savePng(Uint8List bytes, String name) async {
    saved.complete(bytes);
  }

  @override
  Future<void> sharePng(Uint8List bytes, String name, Rect origin) async {
    shareOrigin = origin;
    shared.complete(bytes);
  }
}

class _FixtureRepository implements WorkoutRepository {
  const _FixtureRepository(this.workout);

  final Workout workout;

  @override
  Future<Workout?> get(String id) async => workout.id == id ? workout : null;

  @override
  Future<List<Workout>> list() async => [workout];

  @override
  Future<void> save(Workout workout) => throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

WorkoutCollagePainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_preview)).painter!
        as WorkoutCollagePainter;

Future<void> _pumpEditor(
  WidgetTester tester,
  _Media media, {
  Size size = const Size(430, 932),
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [workoutCollageMediaProvider.overrideWithValue(media)],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: WorkoutCollageScreen(workout: collageFixture()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapControl(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 100);
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

(int, int) _pngSize(Uint8List png) {
  expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final header = ByteData.sublistView(png);
  return (header.getUint32(16), header.getUint32(20));
}

Future<Uint8List> _export(
  WidgetTester tester,
  String button,
  Completer<Uint8List> result,
) async {
  await tester.tap(find.text(button));
  // GPU raster hóa ngoài đồng hồ ảo, còn callback của màn hình chạy khi pump.
  for (var attempt = 0; attempt < 100 && !result.isCompleted; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  expect(result.isCompleted, isTrue, reason: 'Đã xuất PNG qua nút $button');
  return result.future;
}

void main() {
  testWidgets('đổi ba mẫu, đổi tỷ lệ và chọn ảnh từ hai nguồn', (tester) async {
    final photo = collageTestPhoto(AppColors.water);
    final media = _Media(photo: photo);
    await _pumpEditor(tester, media);
    expect(_painter(tester).template, CollageTemplate.glass);
    expect(
      tester.getSize(find.byKey(_preview)).aspectRatio,
      closeTo(9 / 16, 1e-4),
    );

    await _tapControl(tester, 'Đường đi lớn');
    expect(_painter(tester).template, CollageTemplate.centered);
    await _tapControl(tester, 'Post 4:5');
    expect(
      tester.getSize(find.byKey(_preview)).aspectRatio,
      closeTo(4 / 5, 1e-4),
    );
    await _tapControl(tester, 'Thư viện');
    expect(_painter(tester).photo, same(photo));
    await _tapControl(tester, 'Camera');
    expect(
      _painter(tester).photo,
      same(photo),
    ); // Hủy camera giữ ảnh đang dùng.
    expect(media.sources, [ImageSource.gallery, ImageSource.camera]);

    await _tapControl(tester, 'Nhãn dán');
    expect(_painter(tester).template, CollageTemplate.sticker);
    expect(find.text('Thư viện'), findsNothing);
    await _tapControl(tester, 'Thanh mờ');
    expect(_painter(tester).photo, same(photo));
    await _tapControl(tester, 'Bỏ ảnh');
    expect(_painter(tester).photo, isNull);
  });

  testWidgets('kéo, chụm, đổi màu chữ, màu và độ mờ nền', (tester) async {
    await _pumpEditor(tester, _Media());
    final preview = find.byKey(_preview);
    final start = _painter(tester).placement;
    final center = tester.getCenter(preview);
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(20, -20));
    await drag.moveBy(const Offset(24, -20));
    await drag.up();
    await tester.pump();
    final moved = _painter(tester).placement.center;
    expect(moved.dx, greaterThan(start.center.dx));
    expect(moved.dy, lessThan(start.center.dy));

    final left = await tester.startGesture(center - const Offset(20, 0));
    final right = await tester.startGesture(center + const Offset(20, 0));
    await left.moveBy(const Offset(-20, 0));
    await right.moveBy(const Offset(20, 0));
    await left.moveBy(const Offset(-15, 0));
    await right.moveBy(const Offset(15, 0));
    await left.up();
    await right.up();
    await tester.pump();
    expect(_painter(tester).placement.scale, greaterThan(1));

    await _tapControl(tester, 'Đặt lại đường đi');
    expect(_painter(tester).placement, start);
    await _tapControl(tester, 'Vàng');
    expect(_painter(tester).textColor, AppColors.brand);
    await _tapControl(tester, 'Tím');
    expect(_painter(tester).backgroundColor, AppColors.sleep);
    final opacity = find.byKey(const ValueKey('collage-background-opacity'));
    await tester.scrollUntilVisible(opacity, 100);
    await tester.tapAt(tester.getTopRight(opacity) + const Offset(-25, 24));
    await tester.pumpAndSettle();
    expect(_painter(tester).backgroundOpacity, greaterThan(0.4));
  });

  testWidgets('Lưu ảnh và Chia sẻ gửi PNG đúng tỷ lệ đã chọn', (tester) async {
    final media = _Media();
    await _pumpEditor(tester, media);
    final saved = await _export(tester, 'Lưu ảnh', media.saved);
    expect(_pngSize(saved), (1080, 1920));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu ảnh vào thư viện.'), findsOneWidget);

    await _tapControl(tester, 'Post 4:5');
    await _tapControl(tester, 'Nhãn dán');
    final shared = await _export(tester, 'Chia sẻ', media.shared);
    expect(_pngSize(shared), (1080, 1350));
    expect(media.shareOrigin?.isEmpty, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('Chia sẻ từ tổng kết mở đúng buổi tập trong trình tạo', (
    tester,
  ) async {
    const channel = MethodChannel('healthtrack/route');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final workout = collageFixture('sample-walk-vku');
    final app = await pumpApp(
      tester,
      providerOverrides: [
        workoutRepositoryProvider.overrideWithValue(
          _FixtureRepository(workout),
        ),
      ],
    );
    app.container.read(routerProvider).go('/workout/${workout.id}');
    await tester.pumpAndSettle();
    final button = find.text('Chia sẻ');
    await tester.scrollUntilVisible(button, 400);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Tạo ảnh ghép'), findsOneWidget);
    expect(_painter(tester).workout.id, workout.id);
  });

  testWidgets('bố cục vừa iPhone SE và Pro Max ở chế độ sáng và tối', (
    tester,
  ) async {
    for (final size in [const Size(375, 667), const Size(430, 932)]) {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await _pumpEditor(tester, _Media(), size: size, theme: theme);
        expect(find.text('Lưu ảnh').hitTestable(), findsOneWidget);
        expect(find.byKey(_preview).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
