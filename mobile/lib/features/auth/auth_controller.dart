import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/reminder_notification_scheduler.dart';
import 'auth_repository.dart';
import 'user.dart';

/// Trạng thái đăng nhập: `AsyncData(null)` là chưa đăng nhập, `AsyncData(user)` là đã đăng nhập,
/// `AsyncLoading` là đang khôi phục phiên khi mở app.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    if (!await repo.hasSession()) return null;
    try {
      return await repo.me();
    } on DioException catch (e) {
      // Token hỏng hoặc hết hạn hẳn: về màn đăng nhập. Mất mạng: cũng về đăng nhập
      // (token vẫn được giữ nên lần mở sau còn khôi phục được nếu chưa hết hạn).
      if (e.response?.statusCode == 401) await repo.logout();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.login(email, password);
    state = AsyncData(await repo.me());
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.register(email: email, password: password, fullName: fullName);
    state = AsyncData(await repo.me());
  }

  Future<void> updateHeight(double heightCm) async {
    state = AsyncData(
      await ref.read(authRepositoryProvider).updateHeight(heightCm),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
    await _cancelLocalReminders();
  }

  /// Interceptor gọi khi không làm mới được token.
  void onSessionExpired() {
    state = const AsyncData(null);
    unawaited(_cancelLocalReminders());
  }

  Future<void> _cancelLocalReminders() async {
    try {
      await ref.read(reminderNotificationSchedulerProvider).cancelAll();
    } on Exception {
      // Việc dọn lịch local không được chặn luồng đăng xuất.
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
