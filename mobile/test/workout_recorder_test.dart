import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/health/health_providers.dart';
import 'package:healthtrack/features/workout/location_source.dart';
import 'package:healthtrack/features/workout/active_workout_store.dart';
import 'package:healthtrack/features/workout/tracking_session.dart'
    show PauseReason;
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_recorder.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';
import 'package:route_tracker/route_tracker.dart';

import 'helpers/fake_location.dart';

Workout fixture(String id) => Workout.fromJson(
  jsonDecode(File('test/fixtures/workouts/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

RawFix raw(TrackPoint p) => RawFix(
  lat: p.lat,
  lon: p.lon,
  t: p.t,
  accuracy: p.accuracy ?? 5,
  alt: p.alt,
  speed: p.speed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // HapticFeedback cần binding
  late FakeLocationSource source;
  late MemoryActiveWorkoutStore drafts;
  late Directory dir;
  late ProviderContainer container;
  late DateTime now;

  WorkoutRecorder rec() => container.read(workoutRecorderProvider.notifier);
  RecordState st() => container.read(workoutRecorderProvider);

  ProviderContainer make({
    LocationPermission perm = LocationPermission.always,
  }) {
    source = FakeLocationSource(perm: perm);
    drafts = MemoryActiveWorkoutStore();
    dir = Directory.systemTemp.createTempSync('rec');
    final c = ProviderContainer(
      overrides: [
        locationSourceProvider.overrideWithValue(source),
        activeWorkoutStoreProvider.overrideWithValue(drafts),
        workoutRepositoryProvider.overrideWithValue(
          LocalWorkoutRepository(baseDir: () async => dir),
        ),
        // Cân nặng chưa tải: bộ ghi dùng 60 kg mặc định, không gọi mạng
        bodyDataProvider.overrideWith((ref) => Completer<BodyData>().future),
      ],
    );
    // Giữ provider sống suốt test (autoDispose)
    c.listen(workoutRecorderProvider, (_, _) {});
    return c;
  }

  setUp(() => container = make());
  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<void> startRecording() async {
    now = DateTime.utc(2026, 11, 25, 6);
    rec()
      ..clock = (() => now)
      ..countdownStep = Duration.zero;
    await rec().init();
    await rec().startCountdown();
  }

  test('init: đọc quyền, nghe GPS và báo chất lượng tín hiệu', () async {
    await rec().init();
    expect(st().permission, LocationPermission.always);
    expect(source.started, isTrue);
    expect(st().signal, GpsSignal.none);
    final w = fixture('sample-run-han-river');
    source.emit(
      RawFix(
        lat: w.points.first.lat,
        lon: w.points.first.lon,
        t: w.points.first.t,
        accuracy: 6,
      ),
    );
    expect(st().signal, GpsSignal.good);
    source.emit(RawFix(lat: 16, lon: 108, t: w.points.first.t, accuracy: 45));
    expect(st().signal, GpsSignal.weak);
    // Chưa bắt đầu thì không ghi điểm nào
    expect(st().points, isEmpty);
  });

  test('chưa có quyền: không bắt đầu được; xin quyền thì nghe GPS', () async {
    container.dispose();
    container = make(perm: LocationPermission.notDetermined);
    await rec().init();
    expect(source.started, isFalse);
    await rec().startCountdown();
    expect(st().phase, RecordPhase.ready);
    await rec().requestPermission();
    expect(st().permission, LocationPermission.whenInUse);
    expect(source.started, isTrue);
    await rec().openSettings();
    expect(source.openedSettings, 1);
  });

  test(
    'ghi trọn một buổi chạy mẫu, tạm dừng, tiếp tục rồi lưu vào máy',
    () async {
      await startRecording();
      expect(st().phase, RecordPhase.recording);
      expect(source.keepAwake, isTrue);
      final w = fixture('sample-run-han-river');
      for (final p in w.points.take(200)) {
        source.emit(raw(p));
      }
      expect(st().distanceM, greaterThan(500));
      expect(st().movingSeconds, greaterThan(300));
      expect(st().paceSecPerKm, closeTo(333, 50));
      expect(st().points, isNotEmpty);

      rec().pause();
      expect(st().phase, RecordPhase.paused);
      expect(st().pauseReason, PauseReason.manual);
      final dist = st().distanceM;
      source.emit(raw(w.points[201]));
      expect(st().distanceM, dist);
      rec().resume();
      expect(st().phase, RecordPhase.recording);
      for (final p in w.points.skip(202)) {
        source.emit(raw(p));
      }
      final saved = await rec().finish(id: 'run-1');
      expect(saved, isNotNull);
      expect(saved!.distanceM, closeTo(5010, 150));
      expect(saved.sport, Sport.run);
      expect(
        (await container.read(workoutRepositoryProvider).get('run-1'))!
            .distanceM,
        closeTo(saved.distanceM, 0.01), // file JSON làm tròn 2 chữ số
      );
      expect(st().phase, RecordPhase.ready);
      expect(source.keepAwake, isFalse);
      expect(drafts.draft, isNull);
    },
  );

  test('buổi quá ngắn (dưới 20 m) không được lưu', () async {
    await startRecording();
    final w = fixture('sample-walk-vku');
    for (final p in w.points.take(3)) {
      source.emit(raw(p));
    }
    expect(await rec().finish(id: 'tiny'), isNull);
    expect(await container.read(workoutRepositoryProvider).list(), isEmpty);
  });

  test('chọn môn chỉ được lúc chưa bắt đầu', () async {
    await startRecording();
    rec().selectSport(Sport.ride);
    expect(st().sport, Sport.run);
    await rec().discard();
    rec().selectSport(Sport.ride);
    expect(st().sport, Sport.ride);
  });

  test('lưu bản nháp mỗi 20 giây và hỏi lại khi mở lần sau', () async {
    await startRecording();
    final w = fixture('sample-run-han-river');
    for (final p in w.points.take(120)) {
      source.emit(raw(p));
    }
    rec().tick();
    await Future<void>.delayed(Duration.zero);
    expect(drafts.saves, 1);
    now = now.add(const Duration(seconds: 10));
    rec().tick();
    expect(drafts.saves, 1);
    now = now.add(const Duration(seconds: 15));
    rec().tick();
    expect(drafts.saves, 2);

    // App bị tắt rồi mở lại: phiên mới thấy bản nháp
    final draft = drafts.draft!;
    container.dispose();
    container = make();
    drafts.draft = draft;
    await rec().init();
    expect(st().recovered, isNotNull);
    final saved = await rec().saveRecovered(id: 'khoi-phuc');
    expect(saved!.distanceM, closeTo(draft.distanceM, 0.01));
    expect(st().recovered, isNull);
    expect(drafts.draft, isNull);
    expect(
      (await container.read(workoutRepositoryProvider).get('khoi-phuc')),
      isNotNull,
    );
  });

  test('bỏ bản nháp cũ', () async {
    drafts.draft = fixture('sample-walk-vku');
    await rec().init();
    expect(st().recovered, isNotNull);
    await rec().dropRecovered();
    expect(st().recovered, isNull);
    expect(drafts.draft, isNull);
  });
}
