import 'dart:async';

import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/settings_storage.dart';
import '../auth/auth_controller.dart';
import '../health/health_providers.dart';
import '../health/healthkit_sync.dart' show healthBridgeProvider;
import 'activity_algorithms.dart';

const _enabledKey = 'activity_tracking_enabled';

/// Đồng hồ của app; test thay bằng giờ cố định để kết quả không phụ thuộc lúc chạy.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final activitySensorsProvider = Provider<ActivitySensors>(
  (ref) => const ActivitySensors(),
);

/// Trạng thái theo dõi vận động bằng cảm biến của máy.
@immutable
class ActivityTrackingState {
  const ActivityTrackingState({
    this.enabled = false,
    this.available = false,
    this.permission = ActivityPermission.notDetermined,
    this.restAccess = true,
    this.busy = false,
    this.todaySteps,
    this.todayDistanceM,
    this.lastSleep,
    this.sleepSource,
    this.buckets = const [],
    this.appleActiveKcal,
    this.lastSync,
    this.error,
  });

  final bool enabled;

  /// Máy có cảm biến đếm bước.
  final bool available;
  final ActivityPermission permission;

  /// Được đọc quãng nghỉ để ước lượng giấc ngủ (Android cần cấp trong Cài đặt).
  final bool restAccess;
  final bool busy;
  final int? todaySteps;
  final double? todayDistanceM;
  final SleepEstimate? lastSleep;

  /// Nguồn của giấc ngủ đêm qua: `apple`, `google` hoặc `model`.
  final String? sleepSource;

  /// Bước theo từng 15 phút hôm nay (iOS, do Apple đo), để tính calo theo tốc độ đi/chạy.
  final List<StepBucket> buckets;

  /// Năng lượng vận động hôm nay do Apple Health tính, nếu đọc được.
  final double? appleActiveKcal;
  final DateTime? lastSync;
  final String? error;

  ActivityTrackingState copyWith({
    bool? enabled,
    bool? available,
    ActivityPermission? permission,
    bool? restAccess,
    bool? busy,
    int? todaySteps,
    double? todayDistanceM,
    SleepEstimate? lastSleep,
    String? sleepSource,
    List<StepBucket>? buckets,
    double? appleActiveKcal,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
  }) => ActivityTrackingState(
    enabled: enabled ?? this.enabled,
    available: available ?? this.available,
    permission: permission ?? this.permission,
    restAccess: restAccess ?? this.restAccess,
    busy: busy ?? this.busy,
    todaySteps: todaySteps ?? this.todaySteps,
    todayDistanceM: todayDistanceM ?? this.todayDistanceM,
    lastSleep: lastSleep ?? this.lastSleep,
    sleepSource: sleepSource ?? this.sleepSource,
    buckets: buckets ?? this.buckets,
    appleActiveKcal: appleActiveKcal ?? this.appleActiveKcal,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : (error ?? this.error),
  );
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Đếm bước, lấy giấc ngủ và năng lượng rồi đẩy lên máy chủ (nguồn `device`), chạy được cả khi
/// không có Apple Health. Thứ tự ưu tiên, nguồn của hệ điều hành trước, mô hình tự viết sau:
/// - Bước: iPhone dùng CMPedometer của Apple; Android dùng cảm biến đếm bước + tác vụ nền.
/// - Giấc ngủ: Apple Health (nếu đọc được) → Google Sleep API (Android) → mô hình SensibleSleep.
/// - Năng lượng vận động: Apple Health → phương trình ACSM theo quãng đường và tốc độ.
class ActivityTrackingNotifier extends Notifier<ActivityTrackingState> {
  StreamSubscription<int>? _live;

  ActivitySensors get _sensors => ref.read(activitySensorsProvider);

  @override
  ActivityTrackingState build() {
    ref.onDispose(() => _live?.cancel());
    _load();
    return const ActivityTrackingState();
  }

  Future<void> _load() async {
    final enabled =
        await ref.read(settingsStorageProvider).read(_enabledKey) == '1';
    final available = await _sensors.isAvailable();
    final permission = await _sensors.permission();
    final restAccess = await _sensors.restAccess();
    state = state.copyWith(
      enabled: enabled,
      available: available,
      permission: permission,
      restAccess: restAccess,
    );
    if (enabled && permission == ActivityPermission.granted) {
      _startLive();
      await _sensors.startBackground();
    }
  }

  void _startLive() {
    _live?.cancel();
    _live = _sensors.todaySteps().listen(
      (steps) => state = state.copyWith(todaySteps: steps),
      onError: (_) {},
    );
  }

  /// Bật: xin quyền chuyển động rồi đồng bộ ngay. Tắt: dừng đếm, dữ liệu đã gửi được giữ.
  Future<void> setEnabled(bool value) async {
    final storage = ref.read(settingsStorageProvider);
    if (!value) {
      await _live?.cancel();
      _live = null;
      await storage.write(_enabledKey, '0');
      state = state.copyWith(enabled: false, clearError: true);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    final permission = await _sensors.requestPermission();
    if (permission != ActivityPermission.granted) {
      state = state.copyWith(
        busy: false,
        permission: permission,
        error: permission == ActivityPermission.unavailable
            ? 'Máy này không có cảm biến đếm bước'
            : 'Chưa được cấp quyền Chuyển động & thể chất. Bật lại trong Cài đặt của máy.',
      );
      return;
    }
    await storage.write(_enabledKey, '1');
    state = state.copyWith(enabled: true, permission: permission);
    _startLive();
    await _sensors.startBackground();
    // Xin quyền đọc giấc ngủ và năng lượng của Apple Health; bản cài lại (sideload) không có
    // quyền HealthKit thì bỏ qua và dùng mô hình ước lượng
    try {
      final bridge = ref.read(healthBridgeProvider);
      if (await bridge.isAvailable()) await bridge.requestAuthorization();
    } catch (_) {}
    await syncNow();
  }

  /// Gọi khi mở app, quay lại app và định kỳ: chỉ chạy nếu người dùng đã bật.
  Future<void> syncIfEnabled() async {
    final enabled =
        state.enabled ||
        await ref.read(settingsStorageProvider).read(_enabledKey) == '1';
    if (enabled && !state.busy) await syncNow();
  }

  /// Mở Cài đặt để cấp quyền đọc lịch sử màn hình (Android), rồi kiểm tra lại khi quay về.
  Future<void> openRestAccessSettings() => _sensors.openRestAccessSettings();

  Future<void> syncNow({DateTime? now}) async {
    final at = now ?? ref.read(clockProvider)();
    state = state.copyWith(busy: true, clearError: true);
    try {
      final today = DateTime(at.year, at.month, at.day);
      final days = await _sensors.dailySteps(
        today.subtract(const Duration(days: 6)),
        at,
      );
      final buckets = [
        for (final w in await _sensors.stepBuckets(today, at))
          StepBucket(
            start: w.start,
            steps: w.steps,
            distanceM: w.distanceM,
            paceSecPerM: w.paceSecPerM,
          ),
      ];
      final sleepFrom = today.subtract(const Duration(days: 3, hours: 8));
      final apple = await _appleData(sleepFrom, today, at);
      final google = await _sensors.sleepSegments(sleepFrom, at);
      final restAccess = await _sensors.restAccess();

      // Giấc ngủ của 3 đêm gần nhất, mỗi đêm một nguồn theo thứ tự ưu tiên
      final sleeps =
          <String, ({SleepEstimate est, String id, String source})>{};
      void put(SleepEstimate est, String id, String source) {
        final key = _dayKey(est.end);
        final cur = sleeps[key];
        if (cur == null || est.duration > cur.est.duration) {
          sleeps[key] = (est: est, id: id, source: source);
        }
      }

      for (final a in apple.sleep) {
        put(a.est, a.id, 'apple');
      }
      for (final g in google) {
        final key = _dayKey(g.end);
        if (sleeps.containsKey(key)) continue;
        put(SleepEstimate(g.start, g.end), 'device-sleep-$key', 'google');
      }
      final missing = [
        for (var i = 0; i < 3; i++)
          if (!sleeps.containsKey(_dayKey(today.subtract(Duration(days: i)))))
            today.subtract(Duration(days: i)),
      ];
      if (missing.isNotEmpty && restAccess) {
        final events = await _sensors.wakeEvents(sleepFrom, at);
        final history = ref.read(bodyDataProvider).value?.sleeps ?? const [];
        final prior = SleepPrior.fromHistory([
          for (final s in history) (s.startAt.toLocal(), s.endAt.toLocal()),
        ]);
        for (final wake in missing) {
          final est = estimateSleep(
            events,
            wakeDay: wake,
            prior: prior,
            now: at,
          );
          if (est != null) put(est, 'device-sleep-${_dayKey(wake)}', 'model');
        }
      }

      final todayRow = days.where((d) => d.day == _dayKey(today)).firstOrNull;
      if (days.isNotEmpty || sleeps.isNotEmpty) {
        await ref
            .read(dioProvider)
            .post<Object?>(
              '/sync/healthkit',
              data: {
                'source': 'device',
                'steps': [
                  for (final d in days) {'day': d.day, 'steps': d.steps},
                ],
                'sleep': [
                  for (final s in sleeps.values)
                    {
                      'external_id': s.id,
                      'start_at': s.est.start.toUtc().toIso8601String(),
                      'end_at': s.est.end.toUtc().toIso8601String(),
                    },
                ],
              },
            );
        ref
          ..invalidate(todaySummaryProvider)
          ..invalidate(gamificationProvider)
          ..invalidate(bodyDataProvider)
          ..invalidate(stepLogsProvider)
          ..invalidate(sleepLogsProvider);
      }
      final last = sleeps[_dayKey(today)];
      state = state.copyWith(
        busy: false,
        restAccess: restAccess,
        todaySteps: todayRow?.steps,
        todayDistanceM: todayRow?.distanceM,
        lastSleep: last?.est,
        sleepSource: last?.source,
        buckets: buckets,
        appleActiveKcal: apple.activeKcal,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: apiErrorMessage(e));
    }
  }

  /// Giấc ngủ và năng lượng vận động từ Apple Health; rỗng nếu máy không có hoặc app không được
  /// đọc (bản cài lại bằng AltStore/Sideloadly không có quyền HealthKit).
  Future<({List<({SleepEstimate est, String id})> sleep, double? activeKcal})>
  _appleData(DateTime from, DateTime today, DateTime now) async {
    const empty = (
      sleep: <({SleepEstimate est, String id})>[],
      activeKcal: null,
    );
    try {
      final bridge = ref.read(healthBridgeProvider);
      if (!await bridge.isAvailable()) return empty;
      final rows = await bridge.sleep(from, now);
      final kcal = await bridge.activeEnergyKcal(today, now);
      return (
        sleep: [
          for (final r in rows)
            (
              est: SleepEstimate(
                DateTime.parse(r['start_at']! as String).toLocal(),
                DateTime.parse(r['end_at']! as String).toLocal(),
              ),
              id: r['external_id']! as String,
            ),
        ],
        activeKcal: kcal != null && kcal > 0 ? kcal : null,
      );
    } catch (_) {
      return empty;
    }
  }
}

final activityTrackingProvider =
    NotifierProvider<ActivityTrackingNotifier, ActivityTrackingState>(
      ActivityTrackingNotifier.new,
    );

/// Bước chân hôm nay: lấy số lớn hơn giữa cảm biến (trực tiếp) và máy chủ (có thể nhập tay).
final todayStepsProvider = Provider<int?>((ref) {
  final live = ref.watch(activityTrackingProvider.select((s) => s.todaySteps));
  final logs = ref.watch(bodyDataProvider).value?.steps ?? const [];
  final now = ref.watch(clockProvider)();
  final key = _dayKey(now);
  final server = logs.where((s) => s.day == key).firstOrNull?.steps;
  if (live == null) return server;
  if (server == null) return live;
  return live > server ? live : server;
});

/// Năng lượng tiêu hao hôm nay, tính từ hồ sơ, cân nặng gần nhất và bước chân.
final todayEnergyProvider = Provider<EnergyEstimate>((ref) {
  final user = ref.watch(authProvider).value;
  final weight = ref
      .watch(bodyDataProvider)
      .value
      ?.weights
      .firstOrNull
      ?.weightKg;
  final steps = ref.watch(todayStepsProvider) ?? 0;
  final tracking = ref.watch(activityTrackingProvider);
  final live = tracking.todaySteps;
  // Quãng đường đo được chỉ khớp khi số bước hiển thị đúng là số của cảm biến
  final distance = live != null && live == steps
      ? tracking.todayDistanceM
      : null;
  return estimateEnergy(
    steps: steps,
    distanceM: distance,
    buckets: tracking.buckets,
    appleActiveKcal: tracking.appleActiveKcal,
    now: ref.watch(clockProvider)(),
    profile: BodyProfile(
      weightKg: weight,
      heightCm: user?.heightCm,
      birthDate: user?.birthDate,
      gender: user?.gender,
    ),
  );
});
