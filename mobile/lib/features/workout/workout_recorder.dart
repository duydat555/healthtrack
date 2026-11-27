import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:route_tracker/route_tracker.dart';

import '../health/health_providers.dart';
import 'active_workout_store.dart';
import 'location_source.dart';
import 'tracking_session.dart';
import 'workout.dart';
import 'workout_math.dart' as wm;
import 'workout_repository.dart';

/// Giai đoạn của màn ghi hoạt động.
enum RecordPhase {
  /// Chưa bắt đầu: chọn môn, xem bản đồ và tín hiệu GPS.
  ready,

  /// Đếm ngược 3, 2, 1.
  countdown,

  /// Đang ghi.
  recording,

  /// Tạm dừng (thủ công hoặc tự động).
  paused,

  /// Đang lưu buổi tập.
  saving,
}

/// Chất lượng tín hiệu GPS theo sai số của vị trí gần nhất.
enum GpsSignal {
  none('Chưa có GPS'),
  weak('GPS yếu'),
  fair('GPS khá'),
  good('GPS tốt');

  const GpsSignal(this.label);

  final String label;

  static GpsSignal fromAccuracy(double? acc) {
    if (acc == null || acc < 0) return GpsSignal.none;
    if (acc <= 10) return GpsSignal.good;
    if (acc <= 20) return GpsSignal.fair;
    return GpsSignal.weak;
  }
}

class RecordState {
  const RecordState({
    this.phase = RecordPhase.ready,
    this.sport = Sport.run,
    this.permission = LocationPermission.notDetermined,
    this.available = true,
    this.countdown = 0,
    this.movingSeconds = 0,
    this.distanceM = 0,
    this.paceSecPerKm,
    this.pauseReason,
    this.signal = GpsSignal.none,
    this.points = const [],
    this.recovered,
    this.error,
  });

  final RecordPhase phase;
  final Sport sport;
  final LocationPermission permission;

  /// Máy có dịch vụ vị trí (Android hiện chưa có).
  final bool available;
  final int countdown;
  final double movingSeconds;
  final double distanceM;

  /// Nhịp hiện tại (giây/km); null khi chưa đủ dữ liệu.
  final double? paceSecPerKm;
  final PauseReason? pauseReason;
  final GpsSignal signal;
  final List<TrackPoint> points;

  /// Buổi tập chưa lưu của lần trước, đang chờ người dùng quyết định.
  final Workout? recovered;
  final String? error;

  bool get active =>
      phase == RecordPhase.recording || phase == RecordPhase.paused;

  RecordState copyWith({
    RecordPhase? phase,
    Sport? sport,
    LocationPermission? permission,
    bool? available,
    int? countdown,
    double? movingSeconds,
    double? distanceM,
    double? paceSecPerKm,
    bool clearPace = false,
    PauseReason? pauseReason,
    bool clearPause = false,
    GpsSignal? signal,
    List<TrackPoint>? points,
    Workout? recovered,
    bool clearRecovered = false,
    String? error,
    bool clearError = false,
  }) => RecordState(
    phase: phase ?? this.phase,
    sport: sport ?? this.sport,
    permission: permission ?? this.permission,
    available: available ?? this.available,
    countdown: countdown ?? this.countdown,
    movingSeconds: movingSeconds ?? this.movingSeconds,
    distanceM: distanceM ?? this.distanceM,
    paceSecPerKm: clearPace ? null : (paceSecPerKm ?? this.paceSecPerKm),
    pauseReason: clearPause ? null : (pauseReason ?? this.pauseReason),
    signal: signal ?? this.signal,
    points: points ?? this.points,
    recovered: clearRecovered ? null : (recovered ?? this.recovered),
    error: clearError ? null : (error ?? this.error),
  );
}

/// Điều phối một buổi ghi: quyền vị trí, đếm ngược, [TrackingSession], lưu bản nháp định kỳ và
/// lưu buổi tập khi kết thúc.
class WorkoutRecorder extends Notifier<RecordState> {
  // Lưu sẵn khi dựng: riverpod không cho gọi ref.read trong onDispose
  late LocationSource _source;
  late ActiveWorkoutStore _drafts;

  TrackingSession? _session;
  StreamSubscription<RawFix>? _fixes;
  Timer? _ticker;
  var _lastDraftAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Đồng hồ và nhịp đếm ngược, để test điều khiển được (mặc định: giờ hệ thống, 1 giây).
  DateTime Function() clock = DateTime.now;
  Duration countdownStep = const Duration(seconds: 1);

  @override
  RecordState build() {
    _source = ref.read(locationSourceProvider);
    _drafts = ref.read(activeWorkoutStoreProvider);
    ref.onDispose(_dispose);
    return const RecordState();
  }

  void _dispose() {
    _fixes?.cancel();
    _ticker?.cancel();
    _source.setKeepAwake(false);
  }

  /// Gọi khi mở màn: đọc quyền, xem có bản nháp chưa lưu không và bắt đầu nghe GPS để hiện tín hiệu.
  Future<void> init() async {
    final available = await _source.isAvailable();
    final permission = await _source.permission();
    state = state.copyWith(available: available, permission: permission);
    final draft = await _drafts.load();
    if (draft != null && draft.points.length >= 2) {
      state = state.copyWith(recovered: draft);
    }
    if (permission.granted) await _listen();
  }

  Future<void> requestPermission() async {
    final p = await _source.requestPermission();
    state = state.copyWith(permission: p);
    if (p.granted) await _listen();
  }

  Future<void> openSettings() => _source.openSettings();

  void selectSport(Sport sport) {
    if (state.phase != RecordPhase.ready) return;
    state = state.copyWith(sport: sport);
  }

  Future<void> _listen() async {
    if (_fixes != null) return;
    await _source.start();
    _fixes = _source.fixes().listen(
      _onFix,
      onError: (Object e) {
        state = state.copyWith(
          error: 'Không đọc được GPS. Kiểm tra quyền vị trí.',
        );
      },
    );
  }

  void _onFix(RawFix f) {
    final signal = GpsSignal.fromAccuracy(f.accuracy);
    final s = _session;
    if (s == null ||
        state.phase == RecordPhase.ready ||
        state.phase == RecordPhase.countdown) {
      if (signal != state.signal) state = state.copyWith(signal: signal);
      return;
    }
    s.onFix(f);
    _publish(signal: signal);
  }

  void _publish({GpsSignal? signal}) {
    final s = _session!;
    state = state.copyWith(
      phase: s.state == SessionState.paused
          ? RecordPhase.paused
          : RecordPhase.recording,
      movingSeconds: s.movingSeconds,
      distanceM: s.distanceM,
      paceSecPerKm: s.currentPaceSecPerKm(),
      clearPace: s.currentPaceSecPerKm() == null,
      pauseReason: s.pauseReason,
      clearPause: s.pauseReason == null,
      signal: signal ?? state.signal,
      points: s.points,
    );
  }

  /// Bắt đầu: đếm ngược 3 giây rồi ghi.
  Future<void> startCountdown() async {
    if (state.phase != RecordPhase.ready || !state.permission.granted) return;
    await _listen();
    for (var i = 3; i >= 1; i--) {
      state = state.copyWith(phase: RecordPhase.countdown, countdown: i);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(countdownStep);
      if (state.phase != RecordPhase.countdown) return; // đã hủy
    }
    _beginRecording();
  }

  void cancelCountdown() {
    if (state.phase == RecordPhase.countdown) {
      state = state.copyWith(phase: RecordPhase.ready, countdown: 0);
    }
  }

  void _beginRecording() {
    final weight =
        ref.read(bodyDataProvider).value?.weights.firstOrNull?.weightKg ?? 60;
    _session = TrackingSession(sport: state.sport, weightKg: weight)..start();
    _source.setKeepAwake(true);
    HapticFeedback.heavyImpact();
    state = state.copyWith(
      phase: RecordPhase.recording,
      countdown: 0,
      clearError: true,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Mỗi giây: phát hiện đứng yên, cập nhật số liệu và lưu bản nháp. Công khai để test gọi trực tiếp.
  @visibleForTesting
  void tick() {
    final s = _session;
    if (s == null) return;
    final before = s.state;
    s.tick(clock().toUtc());
    if (s.state != before) HapticFeedback.mediumImpact();
    _publish();
    _saveDraftIfDue();
  }

  /// Lưu bản nháp mỗi 20 giây, không chặn giao diện.
  void _saveDraftIfDue() {
    final now = clock();
    if (now.difference(_lastDraftAt) < const Duration(seconds: 20)) return;
    _lastDraftAt = now;
    final draft = _snapshot();
    if (draft != null) _drafts.save(draft);
  }

  Workout? _snapshot() {
    final s = _session;
    if (s == null || s.points.length < 2) return null;
    final dist = s.distanceM, moving = s.movingSeconds;
    return Workout.fromPoints(
      id: 'draft',
      sport: s.sport,
      points: s.points,
      kcal: wm.workoutKcal(
        sport: s.sport,
        distanceM: dist,
        movingSeconds: moving,
        weightKg: s.weightKg,
      ),
    );
  }

  void pause() {
    _session?.pause();
    HapticFeedback.mediumImpact();
    _publish();
  }

  void resume() {
    _session?.resume();
    HapticFeedback.mediumImpact();
    _publish();
  }

  /// Kết thúc và lưu. Trả buổi tập đã lưu, hoặc null nếu quá ngắn (không có gì để lưu).
  Future<Workout?> finish({required String id}) async {
    final s = _session;
    if (s == null || !state.active) return null;
    state = state.copyWith(phase: RecordPhase.saving);
    _ticker?.cancel();
    await _fixes?.cancel();
    _fixes = null;
    await _source.stop();
    await _source.setKeepAwake(false);
    HapticFeedback.heavyImpact();
    final w = s.finish(id: id);
    _session = null;
    final worthSaving = w != null && w.distanceM >= 20;
    if (worthSaving) await ref.read(workoutRepositoryProvider).save(w);
    await _drafts.clear();
    ref.invalidate(workoutsProvider);
    state = const RecordState().copyWith(
      permission: state.permission,
      sport: state.sport,
      available: state.available,
    );
    if (state.permission.granted) await _listen();
    return worthSaving ? w : null;
  }

  /// Bỏ buổi tập đang ghi mà không lưu.
  Future<void> discard() async {
    _ticker?.cancel();
    await _fixes?.cancel();
    _fixes = null;
    await _source.stop();
    await _source.setKeepAwake(false);
    await _drafts.clear();
    _session = null;
    state = const RecordState().copyWith(
      permission: state.permission,
      sport: state.sport,
      available: state.available,
    );
    if (state.permission.granted) await _listen();
  }

  /// Lưu buổi tập chưa lưu của lần trước.
  Future<Workout?> saveRecovered({required String id}) async {
    final d = state.recovered;
    if (d == null) return null;
    final w = Workout.fromJson({...d.toJson(), 'id': id});
    await ref.read(workoutRepositoryProvider).save(w);
    await _drafts.clear();
    ref.invalidate(workoutsProvider);
    state = state.copyWith(clearRecovered: true);
    return w;
  }

  Future<void> dropRecovered() async {
    await _drafts.clear();
    state = state.copyWith(clearRecovered: true);
  }
}

final workoutRecorderProvider =
    NotifierProvider.autoDispose<WorkoutRecorder, RecordState>(
      WorkoutRecorder.new,
    );
