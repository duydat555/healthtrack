import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models.dart';

/// Gọi các endpoint dữ liệu sức khỏe. Thời gian gửi lên là UTC.
class HealthRepository {
  HealthRepository(this._dio);

  final Dio _dio;

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, Object?> query = const {},
  }) async {
    final res = await _dio.get<List<dynamic>>(
      path,
      queryParameters: {
        for (final e in query.entries)
          if (e.value != null) e.key: e.value,
      },
    );
    return [for (final j in res.data!) parse(j as Map<String, dynamic>)];
  }

  String _utc(DateTime t) => t.toUtc().toIso8601String();

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  /// Số phút lệch so với UTC của máy (Việt Nam là 420), để máy chủ chia ngày theo giờ địa phương.
  int get _tzOffset => DateTime.now().timeZoneOffset.inMinutes;

  /// Số liệu hôm nay (theo giờ máy) và tiến độ mục tiêu.
  Future<StatsSummary> statsSummary() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stats/summary',
      queryParameters: {'tz_offset': _tzOffset},
    );
    return StatsSummary.fromJson(res.data!);
  }

  /// Giá trị theo ngày của một chỉ số, cũ trước và hôm nay ở cuối; ngày không có dữ liệu là null.
  Future<List<double?>> statsTrend(String metric, {String range = '7d'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stats/trend',
      queryParameters: {
        'metric': metric,
        'range': range,
        'tz_offset': _tzOffset,
      },
    );
    return [
      for (final p in res.data!['points'] as List<dynamic>)
        ((p as Map<String, dynamic>)['value'] as num?)?.toDouble(),
    ];
  }

  /// Dữ liệu chuỗi xu hướng đầy đủ (ngày, giá trị, đơn vị) cho biểu đồ.
  Future<TrendSeries> statsTrendSeries(
    String metric, {
    String range = '7d',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stats/trend',
      queryParameters: {
        'metric': metric,
        'range': range,
        'tz_offset': _tzOffset,
      },
    );
    return TrendSeries.fromJson(res.data!);
  }

  Future<List<WeightLog>> weights({int limit = 30}) =>
      _list('/weights', WeightLog.fromJson, query: {'limit': limit});

  Future<List<WaterLog>> water({required DateTime from, int limit = 200}) =>
      _list(
        '/water',
        WaterLog.fromJson,
        query: {'from': _utc(from), 'limit': limit},
      );

  Future<List<SleepLog>> sleep({int limit = 14}) =>
      _list('/sleep', SleepLog.fromJson, query: {'limit': limit});

  Future<List<Goal>> goals() =>
      _list('/goals', Goal.fromJson, query: {'is_active': true});

  Future<List<Medication>> medications() =>
      _list('/medications', Medication.fromJson);

  Future<List<MedicationLog>> medicationLogs(int id, {int limit = 20}) => _list(
    '/medications/$id/logs',
    MedicationLog.fromJson,
    query: {'limit': limit},
  );

  Future<List<StepLog>> steps({int limit = 30}) =>
      _list('/steps', StepLog.fromJson, query: {'limit': limit});

  Future<List<MealLog>> meals({int limit = 30}) =>
      _list('/meals', MealLog.fromJson, query: {'limit': limit});

  Future<int> mealCalories({DateTime? day}) async {
    final date = day ?? DateTime.now();
    final response = await _dio.get<Map<String, dynamic>>(
      '/meals/total',
      queryParameters: {'date': _date(date), 'tz_offset': _tzOffset},
    );
    return response.data!['total_calories'] as int;
  }

  Future<void> addSteps(int steps, {required DateTime day}) =>
      _dio.post<void>('/steps', data: {'steps': steps, 'day': _date(day)});

  Future<void> addMeal({
    required String mealType,
    required String name,
    required int calories,
  }) => _dio.post<void>(
    '/meals',
    data: {'meal_type': mealType, 'name': name, 'calories': calories},
  );

  Future<void> addWater(int ml, {DateTime? at}) => _dio.post<void>(
    '/water',
    data: {'amount_ml': ml, if (at != null) 'logged_at': _utc(at)},
  );

  Future<WeightLog?> addWeight(double kg, {DateTime? at}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/weights',
      data: {'weight_kg': kg, if (at != null) 'logged_at': _utc(at)},
    );
    return res.data == null ? null : WeightLog.fromJson(res.data!);
  }

  Future<void> deleteWeight(int id) => _dio.delete<void>('/weights/$id');

  Future<void> deleteWater(int id) => _dio.delete<void>('/water/$id');

  Future<void> deleteSleep(int id) => _dio.delete<void>('/sleep/$id');

  Future<void> addSleep({
    required DateTime start,
    required DateTime end,
    int? quality,
  }) => _dio.post<void>(
    '/sleep',
    data: {'start_at': _utc(start), 'end_at': _utc(end), 'quality': ?quality},
  );

  Future<void> logMedication(int id, {bool taken = true}) =>
      _dio.post<void>('/medications/$id/logs', data: {'taken': taken});

  Future<void> createGoal(
    String metric,
    double target, {
    String period = 'daily',
  }) => _dio.post<void>(
    '/goals',
    data: {'metric': metric, 'target_value': target, 'period': period},
  );

  Future<void> updateGoal(int id, double target) =>
      _dio.patch<void>('/goals/$id', data: {'target_value': target});

  Future<void> deactivateGoal(int id) =>
      _dio.patch<void>('/goals/$id', data: {'is_active': false});

  Future<List<Reminder>> reminders() => _list('/reminders', Reminder.fromJson);

  Future<Reminder> createReminder({
    required String kind,
    required String atTime,
    bool enabled = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/reminders',
      data: {'kind': kind, 'at_time': atTime, 'enabled': enabled},
    );
    return Reminder.fromJson(res.data!);
  }

  Future<Reminder> updateReminder(
    int id, {
    String? kind,
    String? atTime,
    bool? enabled,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/reminders/$id',
      data: {'kind': ?kind, 'at_time': ?atTime, 'enabled': ?enabled},
    );
    return Reminder.fromJson(res.data!);
  }

  Future<void> deleteReminder(int id) => _dio.delete<void>('/reminders/$id');
}

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(dioProvider)),
);
