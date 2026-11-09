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
