import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_repository.dart';
import 'models.dart';

/// Mục tiêu mặc định khi người dùng chưa đặt.
const defaultWaterGoalMl = 2000.0;
const defaultSleepGoalMinutes = 480.0;

DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

@immutable
class TodaySummary {
  const TodaySummary({
    required this.waterMl,
    required this.waterGoalMl,
    required this.sleepMinutes,
    required this.sleepGoalMinutes,
    required this.medsTaken,
    required this.medsTotal,
  });

  final int waterMl;
  final double waterGoalMl;

  /// Giấc ngủ gần nhất (đêm qua), null nếu chưa ghi.
  final int? sleepMinutes;
  final double sleepGoalMinutes;
  final int medsTaken;
  final int medsTotal;

  double get waterProgress => waterMl / waterGoalMl;
  double get sleepProgress =>
      sleepMinutes == null ? 0 : sleepMinutes! / sleepGoalMinutes;
  double get medsProgress => medsTotal == 0 ? 0 : medsTaken / medsTotal;
}

@immutable
class BodyData {
  const BodyData({
    required this.weights,
    required this.sleeps,
    required this.waterByDay,
  });

  /// Mới nhất trước.
  final List<WeightLog> weights;
  final List<SleepLog> sleeps;

  /// 7 ngày gần nhất, cũ trước, hôm nay ở cuối: tổng ml mỗi ngày.
  final List<int> waterByDay;
}

final todaySummaryProvider = FutureProvider.autoDispose<TodaySummary>((
  ref,
) async {
  final repo = ref.watch(healthRepositoryProvider);
  final today = startOfDay(DateTime.now());

  final results = await Future.wait<Object>([
    repo.water(from: today),
    repo.sleep(limit: 1),
    repo.goals(),
    repo.medications(),
  ]);
  final water = results[0] as List<WaterLog>;
  final sleeps = results[1] as List<SleepLog>;
  final goals = results[2] as List<Goal>;
  final meds = (results[3] as List<Medication>)
      .where((m) => m.isActive)
      .toList();

  double goalOf(String metric, double fallback) =>
      goals
          .where((g) => g.metric == metric)
          .map((g) => g.targetValue)
          .firstOrNull ??
      fallback;

  // Thuốc: một liều mỗi ngày, tính đã uống nếu hôm nay có nhật ký taken=true
  final logs = await Future.wait(
    meds.map((m) => repo.medicationLogs(m.id, limit: 10)),
  );
  final taken = logs
      .where((l) => l.any((e) => e.taken && sameDay(e.takenAt, DateTime.now())))
      .length;

  return TodaySummary(
    waterMl: water.fold(0, (a, b) => a + b.amountMl),
    waterGoalMl: goalOf('water', defaultWaterGoalMl),
    sleepMinutes: sleeps.firstOrNull?.durationMinutes,
    sleepGoalMinutes: goalOf('sleep', defaultSleepGoalMinutes),
    medsTaken: taken,
    medsTotal: meds.length,
  );
});

final bodyDataProvider = FutureProvider.autoDispose<BodyData>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  final from = startOfDay(DateTime.now()).subtract(const Duration(days: 6));
  final results = await Future.wait<Object>([
    repo.weights(limit: 30),
    repo.sleep(limit: 14),
    repo.water(from: from),
  ]);
  final water = results[2] as List<WaterLog>;
  final byDay = List<int>.filled(7, 0);
  for (final w in water) {
    final index = startOfDay(w.loggedAt).difference(from).inDays;
    if (index >= 0 && index < 7) byDay[index] += w.amountMl;
  }
  return BodyData(
    weights: results[0] as List<WeightLog>,
    sleeps: results[1] as List<SleepLog>,
    waterByDay: byDay,
  );
});

final goalsProvider = FutureProvider.autoDispose<List<Goal>>(
  (ref) => ref.watch(healthRepositoryProvider).goals(),
);

final medicationsProvider = FutureProvider.autoDispose<List<Medication>>(
  (ref) => ref.watch(healthRepositoryProvider).medications(),
);

/// Làm mới mọi dữ liệu hiển thị sau khi ghi thêm.
void refreshHealthData(WidgetRef ref) {
  ref
    ..invalidate(todaySummaryProvider)
    ..invalidate(bodyDataProvider)
    ..invalidate(goalsProvider)
    ..invalidate(medicationsProvider);
}
