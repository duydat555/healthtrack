import 'dart:async';

import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/settings_storage.dart';
import '../auth/auth_controller.dart';
import '../health/health_providers.dart';
import 'activity_algorithms.dart';

const _enabledKey = 'activity_tracking_enabled';

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
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : (error ?? this.error),
  );
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Đếm bước, ước lượng giấc ngủ từ cảm biến và đẩy lên máy chủ (nguồn `device`), không cần
/// Apple Health. Bước chân hôm nay cập nhật trực tiếp khi đang đi.
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
    if (enabled && permission == ActivityPermission.granted) _startLive();
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
    final at = now ?? DateTime.now();
    state = state.copyWith(busy: true, clearError: true);
    try {
      final today = DateTime(at.year, at.month, at.day);
      final days = await _sensors.dailySteps(
        today.subtract(const Duration(days: 6)),
        at,
      );
      final restAccess = await _sensors.restAccess();
      final rest = restAccess
          ? await _sensors.restIntervals(
              today.subtract(const Duration(days: 3, hours: 6)),
              at,
            )
          : const <RestInterval>[];

      // Giấc ngủ của 3 đêm gần nhất; mỗi đêm một khóa cố định nên gửi lại thì cập nhật, không nhân đôi
      final sleeps = <String, SleepEstimate>{};
      for (var i = 0; i < 3; i++) {
        final wake = today.subtract(Duration(days: i));
        final est = estimateSleep(rest, wakeDay: wake);
        // Đêm nay chưa kết thúc (máy vẫn đang nằm yên) thì chưa gửi
        if (est != null &&
            est.end.isBefore(at.subtract(const Duration(minutes: 5)))) {
          sleeps[_dayKey(wake)] = est;
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
                  for (final e in sleeps.entries)
                    {
                      'external_id': 'device-sleep-${e.key}',
                      'start_at': e.value.start.toUtc().toIso8601String(),
                      'end_at': e.value.end.toUtc().toIso8601String(),
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
      state = state.copyWith(
        busy: false,
        restAccess: restAccess,
        todaySteps: todayRow?.steps,
        todayDistanceM: todayRow?.distanceM,
        lastSleep: sleeps[_dayKey(today)],
        lastSync: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: apiErrorMessage(e));
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
  final now = DateTime.now();
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
    now: DateTime.now(),
    profile: BodyProfile(
      weightKg: weight,
      heightCm: user?.heightCm,
      birthDate: user?.birthDate,
      gender: user?.gender,
    ),
  );
});
