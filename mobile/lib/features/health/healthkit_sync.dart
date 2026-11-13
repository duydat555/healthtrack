import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_bridge/health_bridge.dart';

import '../../core/api_client.dart';
import '../../core/settings_storage.dart';
import 'health_providers.dart';

const _enabledKey = 'healthkit_sync_enabled';

final healthBridgeProvider = Provider<HealthBridge>(
  (ref) => const HealthBridge(),
);

/// Kết quả lần đồng bộ gần nhất, để hiện ở Hồ sơ.
class HealthSyncState {
  const HealthSyncState({
    this.enabled = false,
    this.available = false,
    this.busy = false,
    this.lastSync,
    this.error,
  });

  final bool enabled;

  /// Máy có HealthKit không (iPad và Simulator cũ có thể không có).
  final bool available;
  final bool busy;
  final DateTime? lastSync;
  final String? error;

  HealthSyncState copyWith({
    bool? enabled,
    bool? available,
    bool? busy,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
  }) => HealthSyncState(
    enabled: enabled ?? this.enabled,
    available: available ?? this.available,
    busy: busy ?? this.busy,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : (error ?? this.error),
  );
}

class HealthSyncNotifier extends Notifier<HealthSyncState> {
  @override
  HealthSyncState build() {
    _load();
    return const HealthSyncState();
  }

  Future<void> _load() async {
    final enabled =
        await ref.read(settingsStorageProvider).read(_enabledKey) == '1';
    final available = await ref.read(healthBridgeProvider).isAvailable();
    state = state.copyWith(enabled: enabled, available: available);
  }

  /// Bật đồng bộ: xin quyền rồi đồng bộ ngay. Tắt chỉ dừng đồng bộ, dữ liệu đã có được giữ.
  Future<void> setEnabled(bool value) async {
    if (!value) {
      await ref.read(settingsStorageProvider).write(_enabledKey, '0');
      state = state.copyWith(enabled: false, clearError: true);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final bridge = ref.read(healthBridgeProvider);
      if (!await bridge.isAvailable()) {
        state = state.copyWith(
          busy: false,
          error: 'Thiết bị này không có Apple Health',
        );
        return;
      }
      await bridge.requestAuthorization();
      await ref.read(settingsStorageProvider).write(_enabledKey, '1');
      state = state.copyWith(enabled: true, available: true);
      await syncNow(days: 90);
    } catch (e) {
      state = state.copyWith(busy: false, error: apiErrorMessage(e));
    }
  }

  /// Gọi khi mở app: chỉ đồng bộ nếu người dùng đã bật.
  Future<void> syncIfEnabled() async {
    final enabled =
        state.enabled ||
        await ref.read(settingsStorageProvider).read(_enabledKey) == '1';
    if (enabled && !state.busy) await syncNow();
  }

  Future<void> syncNow({int days = 14}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final now = DateTime.now();
      final batch = await ref
          .read(healthBridgeProvider)
          .read(now.subtract(Duration(days: days)), now);
      if (!batch.isEmpty) {
        await ref
            .read(dioProvider)
            .post<Object?>('/sync/healthkit', data: batch.toJson());
        ref
          ..invalidate(todaySummaryProvider)
          ..invalidate(gamificationProvider)
          ..invalidate(bodyDataProvider)
          ..invalidate(stepLogsProvider)
          ..invalidate(sleepLogsProvider)
          ..invalidate(weightLogsProvider);
      }
      state = state.copyWith(busy: false, lastSync: DateTime.now());
    } catch (e) {
      state = state.copyWith(busy: false, error: apiErrorMessage(e));
    }
  }
}

final healthSyncProvider =
    NotifierProvider<HealthSyncNotifier, HealthSyncState>(
      HealthSyncNotifier.new,
    );
