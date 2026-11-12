import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/reminders/reminder_notification_scheduler.dart';
import 'package:healthtrack/features/reminders/reminder_schedule.dart';

class _FakeGateway implements ReminderNotificationGateway {
  bool permissionGranted = true;
  int initializeCalls = 0;
  int permissionCalls = 0;
  final pendingIds = <int>{};
  final scheduled = <int, ReminderSchedule>{};
  final cancelled = <int>[];

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<Set<int>> pendingReminderNotificationIds() async => {...pendingIds};

  @override
  Future<void> scheduleDaily(
    ReminderSchedule reminder,
    int notificationId,
  ) async {
    pendingIds.add(notificationId);
    scheduled[notificationId] = reminder;
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pendingIds.remove(notificationId);
    scheduled.remove(notificationId);
  }
}

ReminderSchedule _reminder(
  int id, {
  ReminderKind kind = ReminderKind.water,
  int hour = 8,
  int minute = 30,
  bool enabled = true,
}) => ReminderSchedule(
  id: id,
  kind: kind,
  hour: hour,
  minute: minute,
  enabled: enabled,
);

void main() {
  group('ReminderNotificationScheduler', () {
    test(
      'asks permission and schedules enabled reminders with stable IDs',
      () async {
        final gateway = _FakeGateway();
        final scheduler = ReminderNotificationScheduler(gateway);

        final granted = await scheduler.sync([
          _reminder(12),
          _reminder(13, kind: ReminderKind.medication, hour: 21),
          _reminder(14, kind: ReminderKind.sleep, enabled: false),
        ]);

        expect(granted, isTrue);
        expect(gateway.initializeCalls, 1);
        expect(gateway.permissionCalls, 1);
        expect(gateway.scheduled.keys.toSet(), {
          ReminderNotificationScheduler.notificationIdFor(12),
          ReminderNotificationScheduler.notificationIdFor(13),
        });
        expect(
          gateway
              .scheduled[ReminderNotificationScheduler.notificationIdFor(13)]
              ?.hour,
          21,
        );
      },
    );

    test(
      'resync cancels deleted or disabled reminders and updates changed time',
      () async {
        final gateway = _FakeGateway();
        final scheduler = ReminderNotificationScheduler(gateway);
        await scheduler.sync([_reminder(1), _reminder(2)]);

        await scheduler.sync([
          _reminder(1, hour: 9),
          _reminder(3, enabled: false),
        ]);

        expect(gateway.cancelled, [
          ReminderNotificationScheduler.notificationIdFor(2),
        ]);
        expect(gateway.scheduled.keys.toSet(), {
          ReminderNotificationScheduler.notificationIdFor(1),
        });
        expect(gateway.scheduled.values.single.hour, 9);
        expect(gateway.initializeCalls, 1);
      },
    );

    test(
      'permission denial prevents schedules and clears existing enabled ones',
      () async {
        final gateway = _FakeGateway()..permissionGranted = false;
        final id = ReminderNotificationScheduler.notificationIdFor(7);
        gateway.pendingIds.add(id);
        final scheduler = ReminderNotificationScheduler(gateway);

        final granted = await scheduler.sync([_reminder(7)]);

        expect(granted, isFalse);
        expect(gateway.scheduled, isEmpty);
        expect(gateway.pendingIds, isEmpty);
        expect(gateway.cancelled, [id]);
      },
    );

    test(
      'empty reminder list cancels schedules without requesting permission',
      () async {
        final gateway = _FakeGateway();
        final id = ReminderNotificationScheduler.notificationIdFor(8);
        gateway.pendingIds.add(id);
        final scheduler = ReminderNotificationScheduler(gateway);

        expect(await scheduler.sync([]), isTrue);
        expect(gateway.cancelled, [id]);
        expect(gateway.permissionCalls, 0);
      },
    );
  });

  group('ReminderSchedule.fromApi', () {
    test('parses API time and reminder kind', () {
      final reminder = ReminderSchedule.fromApi(
        id: 9,
        kind: 'sleep',
        atTime: '22:15:00',
        enabled: true,
      );

      expect(reminder.kind, ReminderKind.sleep);
      expect(reminder.hour, 22);
      expect(reminder.minute, 15);
    });

    test('rejects invalid kind and invalid time', () {
      expect(
        () => ReminderSchedule.fromApi(
          id: 1,
          kind: 'other',
          atTime: '08:00:00',
          enabled: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReminderSchedule.fromApi(
          id: 1,
          kind: 'water',
          atTime: '24:00:00',
          enabled: true,
        ),
        throwsFormatException,
      );
    });
  });
}
