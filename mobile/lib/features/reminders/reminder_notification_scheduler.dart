import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_notification_service.dart';
import 'reminder_schedule.dart';

abstract interface class ReminderNotificationGateway {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<Set<int>> pendingReminderNotificationIds();

  Future<void> scheduleDaily(ReminderSchedule reminder, int notificationId);

  Future<void> cancel(int notificationId);
}

/// Giữ lịch thông báo của hệ điều hành đồng bộ với toàn bộ danh sách reminders.
class ReminderNotificationScheduler {
  ReminderNotificationScheduler(this._gateway);

  final ReminderNotificationGateway _gateway;
  Future<void>? _initialization;

  static const _notificationIdPrefix = 0x40000000;
  static const _notificationIdValueMask = 0x3fffffff;

  static int notificationIdFor(int reminderId) {
    if (reminderId <= 0 || reminderId > _notificationIdValueMask) {
      throw RangeError.range(
        reminderId,
        1,
        _notificationIdValueMask,
        'reminderId',
      );
    }
    return _notificationIdPrefix | reminderId;
  }

  Future<bool> sync(Iterable<ReminderSchedule> reminders) async {
    _initialization ??= _gateway.initialize();
    await _initialization;

    final enabled = reminders.where((reminder) => reminder.enabled).toList();
    final desiredIds = {
      for (final reminder in enabled) notificationIdFor(reminder.id),
    };
    final existingIds = await _gateway.pendingReminderNotificationIds();

    for (final id in existingIds.difference(desiredIds)) {
      await _gateway.cancel(id);
    }
    if (enabled.isEmpty) return true;
    if (!await _gateway.requestPermission()) {
      for (final id in existingIds.intersection(desiredIds)) {
        await _gateway.cancel(id);
      }
      return false;
    }

    for (final reminder in enabled) {
      await _gateway.scheduleDaily(reminder, notificationIdFor(reminder.id));
    }
    return true;
  }

  Future<void> cancelAll() async {
    _initialization ??= _gateway.initialize();
    await _initialization;
    for (final id in await _gateway.pendingReminderNotificationIds()) {
      await _gateway.cancel(id);
    }
  }
}

final reminderNotificationGatewayProvider =
    Provider<ReminderNotificationGateway>(
      (ref) => ReminderNotificationService(),
    );

final reminderNotificationSchedulerProvider =
    Provider<ReminderNotificationScheduler>(
      (ref) => ReminderNotificationScheduler(
        ref.watch(reminderNotificationGatewayProvider),
      ),
    );
