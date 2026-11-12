import 'package:flutter/foundation.dart';

DateTime _time(Object? v) => DateTime.parse(v! as String).toLocal();

@immutable
class WeightLog {
  const WeightLog({
    required this.id,
    required this.weightKg,
    required this.bmi,
    required this.loggedAt,
  });

  factory WeightLog.fromJson(Map<String, dynamic> j) => WeightLog(
    id: j['id'] as int,
    weightKg: (j['weight_kg'] as num).toDouble(),
    bmi: (j['bmi'] as num?)?.toDouble(),
    loggedAt: _time(j['logged_at']),
  );

  final int id;
  final double weightKg;
  final double? bmi;
  final DateTime loggedAt;
}

@immutable
class WaterLog {
  const WaterLog({
    required this.id,
    required this.amountMl,
    required this.loggedAt,
  });

  factory WaterLog.fromJson(Map<String, dynamic> j) => WaterLog(
    id: j['id'] as int,
    amountMl: j['amount_ml'] as int,
    loggedAt: _time(j['logged_at']),
  );

  final int id;
  final int amountMl;
  final DateTime loggedAt;
}

@immutable
class SleepLog {
  const SleepLog({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.quality,
    required this.durationMinutes,
  });

  factory SleepLog.fromJson(Map<String, dynamic> j) => SleepLog(
    id: j['id'] as int,
    startAt: _time(j['start_at']),
    endAt: _time(j['end_at']),
    quality: j['quality'] as int?,
    durationMinutes: j['duration_minutes'] as int,
  );

  final int id;
  final DateTime startAt;
  final DateTime endAt;
  final int? quality;
  final int durationMinutes;
}

@immutable
class StepLog {
  const StepLog({required this.id, required this.steps, required this.day});

  factory StepLog.fromJson(Map<String, dynamic> json) => StepLog(
    id: json['id'] as int,
    steps: json['steps'] as int,
    day: json['day'] as String,
  );

  final int id;
  final int steps;
  final String day;
}

@immutable
class MealLog {
  const MealLog({
    required this.id,
    required this.mealType,
    required this.name,
    required this.calories,
    required this.loggedAt,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) => MealLog(
    id: json['id'] as int,
    mealType: json['meal_type'] as String,
    name: json['name'] as String,
    calories: json['calories'] as int,
    loggedAt: _time(json['logged_at']),
  );

  final int id;
  final String mealType;
  final String name;
  final int calories;
  final DateTime loggedAt;
}

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.metric,
    required this.period,
    required this.targetValue,
    required this.isActive,
    required this.unit,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as int,
    metric: j['metric'] as String,
    period: j['period'] as String,
    targetValue: (j['target_value'] as num).toDouble(),
    isActive: j['is_active'] as bool,
    unit: j['unit'] as String,
  );

  final int id;
  final String metric;
  final String period;
  final double targetValue;
  final bool isActive;
  final String unit;
}

@immutable
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.isActive,
  });

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    id: j['id'] as int,
    name: j['name'] as String,
    dosage: j['dosage'] as String?,
    isActive: j['is_active'] as bool,
  );

  final int id;
  final String name;
  final String? dosage;
  final bool isActive;
}

@immutable
class MedicationLog {
  const MedicationLog({required this.takenAt, required this.taken});

  factory MedicationLog.fromJson(Map<String, dynamic> j) =>
      MedicationLog(takenAt: _time(j['taken_at']), taken: j['taken'] as bool);

  final DateTime takenAt;
  final bool taken;
}

/// Tiến độ một mục tiêu do máy chủ tính (`/stats/summary`).
@immutable
class GoalProgress {
  const GoalProgress({
    required this.metric,
    required this.targetValue,
    required this.currentValue,
  });

  factory GoalProgress.fromJson(Map<String, dynamic> j) => GoalProgress(
    metric: j['metric'] as String,
    targetValue: (j['target_value'] as num).toDouble(),
    currentValue: (j['current_value'] as num).toDouble(),
  );

  final String metric;
  final double targetValue;
  final double currentValue;
}

/// Số liệu một ngày theo múi giờ của máy (`/stats/summary`).
@immutable
class StatsSummary {
  const StatsSummary({
    required this.waterMl,
    required this.sleepMinutes,
    required this.medsTaken,
    required this.goals,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> j) => StatsSummary(
    waterMl: j['water_ml'] as int,
    sleepMinutes: j['sleep_minutes'] as int,
    medsTaken: (j['medications'] as Map<String, dynamic>)['taken'] as int,
    goals: [
      for (final g in j['goals'] as List<dynamic>)
        GoalProgress.fromJson(g as Map<String, dynamic>),
    ],
  );

  final int waterMl;

  /// Tổng phút ngủ của các giấc kết thúc trong ngày.
  final int sleepMinutes;
  final int medsTaken;
  final List<GoalProgress> goals;
}

/// Một lịch nhắc nhở hằng ngày của người dùng (`/reminders`).
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  factory Reminder.fromJson(Map<String, dynamic> j) {
    final raw = (j['at_time'] as String).split(':');
    return Reminder(
      id: j['id'] as int,
      kind: j['kind'] as String,
      hour: int.parse(raw[0]),
      minute: int.parse(raw[1]),
      enabled: j['enabled'] as bool,
    );
  }

  final int id;
  final String kind;
  final int hour;
  final int minute;
  final bool enabled;

  /// Chuỗi giờ hiển thị `HH:mm`.
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Chuỗi giờ gửi lên API `HH:mm:00`.
  String get apiTime => '$formattedTime:00';
}

/// Một điểm dữ liệu theo ngày của biểu đồ xu hướng (`/stats/trend`).
@immutable
class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
    date: DateTime.parse(j['date'] as String),
    value: (j['value'] as num?)?.toDouble(),
  );

  final DateTime date;
  final double? value;
}

/// Chuỗi xu hướng theo ngày từ `/stats/trend`.
@immutable
class TrendSeries {
  const TrendSeries({
    required this.metric,
    required this.unit,
    required this.range,
    required this.points,
  });

  factory TrendSeries.fromJson(Map<String, dynamic> j) => TrendSeries(
    metric: (j['metric'] as String?) ?? '',
    unit: (j['unit'] as String?) ?? '',
    range: (j['range'] as String?) ?? '7d',
    points: [
      for (final p in j['points'] as List<dynamic>)
        TrendPoint.fromJson(p as Map<String, dynamic>),
    ],
  );

  final String metric;
  final String unit;
  final String range;
  final List<TrendPoint> points;
}
