import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/workout/collage/workout_collage_painter.dart';
import 'package:healthtrack/features/workout/workout.dart';

import 'helpers/workout_collage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('giữ các đoạn GPS và đọc được bản ghi chỉ có polyline', () {
    final workout = collageFixture();
    final detailed = collageRoutePath(workout)!;
    expect(detailed.computeMetrics().length, 2);
    final compact = collageRoutePath(
      Workout.fromJson(workout.toJson(withPoints: false)),
    )!;
    expect(compact.computeMetrics().length, 1);
    for (final path in [detailed, compact]) {
      final bounds = path.getBounds();
      expect(bounds.center.dx, closeTo(0, 1e-5));
      expect(bounds.center.dy, closeTo(0, 1e-5));
      expect(bounds.longestSide, closeTo(1, 1e-5));
    }
    expect(
      collageRoutePath(
        Workout.fromJson({
          ...workout.toJson(withPoints: false),
          'polyline': '_',
        }),
      ),
      isNull,
    );
  });

  test('kéo và chụm giữ tiêu điểm, giới hạn độ lớn và vị trí', () {
    const initial = (center: Offset(0.5, 0.45), scale: 1.0);
    final moved = transformCollageRoute(
      initial: initial,
      initialFocalPoint: const Offset(0.3, 0.35),
      focalPoint: const Offset(0.4, 0.55),
      pinchScale: 2,
    );
    expect(moved.center.dx, closeTo(0.8, 1e-9));
    expect(moved.center.dy, closeTo(0.75, 1e-9));
    expect(moved.scale, 2);
    expect(
      transformCollageRoute(
        initial: initial,
        initialFocalPoint: initial.center,
        focalPoint: const Offset(-1, 2),
        pinchScale: 10,
      ),
      (center: const Offset(0.08, 0.92), scale: maxRouteScale),
    );
    expect(
      transformCollageRoute(
        initial: initial,
        initialFocalPoint: initial.center,
        focalPoint: initial.center,
        pinchScale: 0.01,
      ).scale,
      minRouteScale,
    );
  });

  test('mẫu Đường cam giữ nguyên ảnh và chỉ vẽ nét cam', () async {
    final workout = collageFixture('sample-ride-my-khe');
    final photo = collageTestPhoto(AppColors.water);
    addTearDown(photo.dispose);
    final painter = WorkoutCollagePainter(
      workout: workout,
      route: collageRoutePath(workout),
      template: CollageTemplate.route,
      placement: (center: CollageTemplate.route.routeCenter, scale: 1),
      photo: photo,
      textColor: AppColors.ink,
      backgroundColor: AppColors.card,
      backgroundOpacity: 0.9,
    );
    final png = await painter.renderPng(CollageFormat.story);
    final codec = await ui.instantiateImageCodec(png);
    final decoded = (await codec.getNextFrame()).image;
    try {
      final data = (await decoded.toByteData())!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      // Độ mờ nền không có tác dụng: góc ảnh vẫn là màu gốc.
      expect(bytes.take(4), [0x32, 0xD4, 0xE8, 255]);
      var orange = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0x55 && bytes[i + 2] == 0) {
          orange++;
        }
      }
      expect(orange, greaterThan(500));
    } finally {
      decoded.dispose();
      codec.dispose();
    }
  });

  test('PNG có kích thước chính xác và nền riêng cho từng mẫu', () async {
    final workout = collageFixture('sample-ride-my-khe');
    final route = collageRoutePath(workout);
    final photo = collageTestPhoto(AppColors.water);
    addTearDown(photo.dispose);
    for (final format in CollageFormat.values) {
      for (final template in CollageTemplate.values) {
        final painter = WorkoutCollagePainter(
          workout: workout,
          route: route,
          template: template,
          placement: (center: template.routeCenter, scale: 1),
          photo: photo,
          textColor: AppColors.ink,
          backgroundColor: AppColors.card,
          backgroundOpacity: 0,
        );
        final png = await painter.renderPng(format);
        final codec = await ui.instantiateImageCodec(png);
        final decoded = (await codec.getNextFrame()).image;
        try {
          expect(decoded.width, 1080);
          expect(decoded.height, format == CollageFormat.story ? 1920 : 1350);
          final data = (await decoded.toByteData())!;
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final sticker = template == CollageTemplate.sticker;
          expect(
            bytes.take(4),
            sticker ? [0, 0, 0, 0] : [0x32, 0xD4, 0xE8, 255],
          );
          if (sticker) {
            // Ngoài các góc trong suốt, PNG phải có nội dung nhìn thấy được.
            expect(
              Iterable.generate(
                bytes.length ~/ 4,
                (i) => bytes[i * 4 + 3],
              ).any((alpha) => alpha == 255),
              isTrue,
            );
          }
          if (template == CollageTemplate.glass) {
            final insideBar = ((decoded.height - 85) * decoded.width + 210) * 4;
            expect(bytes[insideBar + 1], lessThan(0xD4));
          }
        } finally {
          decoded.dispose();
          codec.dispose();
        }
      }
    }
  });
}
