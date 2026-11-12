import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/reminders/reminder_notification_scheduler.dart';
import 'package:healthtrack/features/reminders/reminder_repository.dart';
import 'package:healthtrack/features/reminders/reminder_schedule.dart';

class _FakeGateway implements ReminderNotificationGateway {
  final pendingIds = <int>{};
  final scheduled = <int, ReminderSchedule>{};
  final cancelled = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

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

class _FakeReminderApi {
  final requests = <RequestOptions>[];
  final reminders = <Map<String, dynamic>>[];
  var nextId = 1;

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          dynamic data;
          final id = _pathId(options.path);
          switch (options.method) {
            case 'GET':
              data = reminders.map((reminder) => {...reminder}).toList();
            case 'POST':
              final body = options.data as Map<String, dynamic>;
              final created = {
                'id': nextId++,
                ...body,
                'created_at': '2026-11-11T00:00:00',
              };
              reminders.add(created);
              data = created;
            case 'PATCH':
              final reminder = reminders.singleWhere(
                (item) => item['id'] == id,
              );
              reminder.addAll(options.data as Map<String, dynamic>);
              data = {...reminder};
            case 'DELETE':
              reminders.removeWhere((item) => item['id'] == id);
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: options.method == 'DELETE' ? 204 : 200,
              data: data,
            ),
          );
        },
      ),
    );
    return dio;
  }

  int? _pathId(String path) {
    final parts = path.split('/');
    return parts.length > 2 ? int.tryParse(parts.last) : null;
  }
}

void main() {
  test('API list/create/update/delete keeps local schedules in sync', () async {
    final api = _FakeReminderApi();
    final gateway = _FakeGateway();
    final repository = ReminderRepository(
      api.createDio(),
      ReminderNotificationScheduler(gateway),
    );

    final created = await repository.create(
      kind: ReminderKind.water,
      hour: 6,
      minute: 45,
    );
    final notificationId = ReminderNotificationScheduler.notificationIdFor(
      created.id,
    );
    expect(created.hour, 6);
    expect(gateway.scheduled[notificationId]?.minute, 45);
    expect(api.requests.map((request) => request.method), ['POST', 'GET']);
    expect(api.requests.first.data['at_time'], '06:45:00');

    await repository.update(created.id, hour: 7, minute: 30, enabled: true);
    expect(gateway.scheduled[notificationId]?.hour, 7);
    expect(gateway.scheduled[notificationId]?.minute, 30);

    await repository.list();
    await repository.delete(created.id);
    expect(gateway.pendingIds, isEmpty);
    expect(gateway.cancelled, contains(notificationId));
  });

  test(
    'API list parses snake_case time and syncs existing reminders',
    () async {
      final api = _FakeReminderApi()
        ..reminders.add({
          'id': 42,
          'kind': 'medication',
          'at_time': '20:10:00',
          'enabled': true,
          'created_at': '2026-11-11T00:00:00',
        });
      final gateway = _FakeGateway();
      final repository = ReminderRepository(
        api.createDio(),
        ReminderNotificationScheduler(gateway),
      );

      final reminders = await repository.list();

      expect(reminders.single.id, 42);
      expect(reminders.single.kind, ReminderKind.medication);
      expect(gateway.scheduled.values.single.hour, 20);
      expect(gateway.scheduled.values.single.minute, 10);
    },
  );
}
