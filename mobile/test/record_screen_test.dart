import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/features/health/health_providers.dart';
import 'package:healthtrack/features/workout/active_workout_store.dart';
import 'package:healthtrack/features/workout/location_source.dart';
import 'package:healthtrack/features/workout/record_screen.dart';
import 'package:healthtrack/features/workout/workout_recorder.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';
import 'package:route_tracker/route_tracker.dart';

import 'helpers/fake_location.dart';

void main() {
  late FakeLocationSource source;
  late Directory dir;

  Future<void> pump(
    WidgetTester tester, {
    LocationPermission perm = LocationPermission.always,
  }) async {
    source = FakeLocationSource(perm: perm);
    dir = Directory.systemTemp.createTempSync('recui');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationSourceProvider.overrideWithValue(source),
          activeWorkoutStoreProvider.overrideWithValue(
            MemoryActiveWorkoutStore(),
          ),
          workoutRepositoryProvider.overrideWithValue(
            LocalWorkoutRepository(baseDir: () async => dir),
          ),
          bodyDataProvider.overrideWith((ref) => Completer<BodyData>().future),
          workoutRecorderProvider.overrideWith(
            () => WorkoutRecorder()..countdownStep = Duration.zero,
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const RecordScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('chưa cấp quyền: hiện nút xin quyền và chưa cho bắt đầu', (
    tester,
  ) async {
    await pump(tester, perm: LocationPermission.notDetermined);
    expect(find.text('Cho phép vị trí'), findsOneWidget);
    await tester.tap(find.text('Cho phép vị trí'));
    await tester.pump();
    await tester.pump();
    expect(source.started, isTrue);
    expect(find.text('Cho phép vị trí'), findsNothing);
  });

  testWidgets('đã có quyền: hiện số liệu ban đầu và nút Bắt đầu', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Bắt đầu'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('Chưa có GPS'), findsOneWidget);
  });

  testWidgets('bắt đầu rồi tạm dừng đổi nhãn nút', (tester) async {
    await pump(tester);
    final sem = tester.ensureSemantics();
    await tester.tap(find.text('Bắt đầu'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.bySemanticsLabel('Tạm dừng'), findsOneWidget);
    expect(find.byType(HoldToFinishButton), findsOneWidget);
    // Hủy ticker trước khi kết thúc test
    await tester.pumpWidget(const SizedBox());
    sem.dispose();
  });
}
