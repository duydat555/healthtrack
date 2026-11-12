import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'reminder_notification_scheduler.dart';
import 'reminder_schedule.dart';

/// Đọc và thay đổi nhắc nhở qua API; mọi thay đổi đều đồng bộ lại lịch local.
class ReminderRepository {
  ReminderRepository(this._dio, this._scheduler);

  final Dio _dio;
  final ReminderNotificationScheduler _scheduler;

  Future<List<ReminderSchedule>> list() async {
    final reminders = await _fetchAll();
    await _scheduler.sync(reminders);
    return reminders;
  }

  Future<ReminderSchedule> create({
    required ReminderKind kind,
    required int hour,
    required int minute,
    bool enabled = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/reminders',
      data: {
        'kind': kind.apiValue,
        'at_time': _formatTime(hour, minute),
        'enabled': enabled,
      },
    );
    final created = ReminderSchedule.fromJson(response.data!);
    await _syncAfterMutation();
    return created;
  }

  Future<ReminderSchedule> update(
    int id, {
    ReminderKind? kind,
    int? hour,
    int? minute,
    bool? enabled,
  }) async {
    if ((hour == null) != (minute == null)) {
      throw ArgumentError('Khi đổi giờ cần cung cấp cả giờ và phút');
    }
    final data = <String, dynamic>{};
    if (kind != null) data['kind'] = kind.apiValue;
    if (hour case final requestedHour?) {
      data['at_time'] = _formatTime(requestedHour, minute!);
    }
    if (enabled != null) data['enabled'] = enabled;
    if (data.isEmpty) {
      throw ArgumentError('Cần cung cấp ít nhất một trường để cập nhật');
    }
    final response = await _dio.patch<Map<String, dynamic>>(
      '/reminders/$id',
      data: data,
    );
    final updated = ReminderSchedule.fromJson(response.data!);
    await _syncAfterMutation();
    return updated;
  }

  Future<void> delete(int id) async {
    await _dio.delete<void>('/reminders/$id');
    await _syncAfterMutation();
  }

  Future<List<ReminderSchedule>> _fetch({
    required int limit,
    required int offset,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/reminders',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data ?? const <dynamic>[])
        .map((item) => ReminderSchedule.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ReminderSchedule>> _fetchAll() async {
    const pageSize = 200;
    final reminders = <ReminderSchedule>[];
    var offset = 0;
    while (true) {
      final page = await _fetch(limit: pageSize, offset: offset);
      reminders.addAll(page);
      if (page.length < pageSize) return reminders;
      offset += pageSize;
    }
  }

  Future<void> _syncAfterMutation() async {
    final reminders = await _fetchAll();
    await _scheduler.sync(reminders);
  }

  static String _formatTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw RangeError('Giờ nhắc phải nằm trong khoảng 00:00 đến 23:59');
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(
    ref.watch(dioProvider),
    ref.watch(reminderNotificationSchedulerProvider),
  ),
);
