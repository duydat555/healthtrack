import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/settings_storage.dart';
import '../health/health_providers.dart';
import 'coach_models.dart';
import 'coach_repository.dart';

class CoachState {
  const CoachState({this.messages = const [], this.busy = false, this.status});

  final List<ChatMessage> messages;
  final bool busy;

  /// Việc Coach đang làm ("Đang xem số liệu...").
  final String? status;

  CoachState copyWith({
    List<ChatMessage>? messages,
    bool? busy,
    String? status,
    bool clearStatus = false,
  }) => CoachState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    status: clearStatus ? null : (status ?? this.status),
  );
}

const _toolStatus = {
  'get_stats': 'Đang xem số liệu của bạn...',
  'get_goals': 'Đang xem mục tiêu...',
  'log_entry': 'Đang ghi giúp bạn...',
};

const _privateKey = 'coach_private_mode';

/// Chế độ riêng tư: khi bật, Coach trả lời bằng model chạy trên Mac của bạn thay vì Claude.
class PrivateModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsStorageProvider).read(_privateKey).then((v) {
      if (v == '1') state = true;
    });
    return false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(settingsStorageProvider)
        .write(_privateKey, value ? '1' : '0');
  }
}

final privateModeProvider = NotifierProvider<PrivateModeNotifier, bool>(
  PrivateModeNotifier.new,
);

final coachProvidersProvider = FutureProvider.autoDispose<CoachProviders>(
  (ref) => ref.watch(coachRepositoryProvider).providers(),
);

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  void _replaceLast(ChatMessage Function(ChatMessage) edit) {
    final list = [...state.messages];
    list[list.length - 1] = edit(list.last);
    state = state.copyWith(messages: list);
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.busy) return;
    // Lịch sử gửi lên không gồm lượt trả lời trống/lỗi
    final history = [
      ...state.messages.where((m) => m.text.isNotEmpty),
      ChatMessage(fromUser: true, text: text),
    ];
    state = state.copyWith(
      messages: [
        ...history,
        const ChatMessage(fromUser: false, text: ''),
      ],
      busy: true,
      clearStatus: true,
    );
    try {
      final provider = ref.read(privateModeProvider) ? 'local' : 'auto';
      await for (final e
          in ref
              .read(coachRepositoryProvider)
              .chat(history, provider: provider)) {
        switch (e) {
          case CoachMeta(:final provider):
            _replaceLast((m) => m.copyWith(source: provider));
          case CoachText(:final text):
            _replaceLast((m) => m.copyWith(text: m.text + text));
            state = state.copyWith(clearStatus: true);
          case CoachTool(:final name):
            state = state.copyWith(status: _toolStatus[name]);
          case CoachLogged(:final metric):
            _replaceLast((m) => m.copyWith(logged: [...m.logged, metric]));
            _refreshData();
          case CoachError(:final message):
            _replaceLast(
              (m) => m.copyWith(text: m.text.isEmpty ? message : m.text),
            );
          case CoachDone():
            break;
        }
      }
    } catch (e) {
      _replaceLast(
        (m) => m.copyWith(
          text: e is CoachException ? e.message : apiErrorMessage(e),
        ),
      );
    } finally {
      state = state.copyWith(busy: false, clearStatus: true);
    }
  }

  void _refreshData() {
    ref
      ..invalidate(todaySummaryProvider)
      ..invalidate(gamificationProvider)
      ..invalidate(bodyDataProvider)
      ..invalidate(waterLogsProvider)
      ..invalidate(weightLogsProvider)
      ..invalidate(sleepLogsProvider)
      ..invalidate(stepLogsProvider)
      ..invalidate(mealLogsProvider);
  }

  void clear() => state = const CoachState();
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(
  CoachController.new,
);

final weeklyInsightProvider = FutureProvider.autoDispose<WeeklyInsight>(
  (ref) => ref.watch(coachRepositoryProvider).weekly(),
);
