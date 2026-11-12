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
  final results = await Future.wait<Object>([
    repo.statsSummary(),
    repo.medications(),
  ]);
  final stats = results[0] as StatsSummary;
  final activeMeds = (results[1] as List<Medication>)
      .where((m) => m.isActive)
      .length;

  double goalOf(String metric, double fallback) =>
      stats.goals
          .where((g) => g.metric == metric)
          .map((g) => g.targetValue)
          .firstOrNull ??
      fallback;

  return TodaySummary(
    waterMl: stats.waterMl,
    waterGoalMl: goalOf('water', defaultWaterGoalMl),
    // Máy chủ cộng phút các giấc ngủ kết thúc hôm nay; 0 nghĩa là chưa ghi giấc nào
    sleepMinutes: stats.sleepMinutes > 0 ? stats.sleepMinutes : null,
    sleepGoalMinutes: goalOf('sleep', defaultSleepGoalMinutes),
    medsTaken: stats.medsTaken,
    // Một liều mỗi ngày cho mỗi thuốc đang dùng; uống nhiều hơn thì tổng không nhỏ hơn số đã uống
    medsTotal: activeMeds > stats.medsTaken ? activeMeds : stats.medsTaken,
  );
});

final bodyDataProvider = FutureProvider.autoDispose<BodyData>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  final results = await Future.wait<Object>([
    repo.weights(limit: 30),
    repo.sleep(limit: 14),
    repo.statsTrend('water'),
  ]);
  final water = results[2] as List<double?>;
  return BodyData(
    weights: results[0] as List<WeightLog>,
    sleeps: results[1] as List<SleepLog>,
    waterByDay: [for (final v in water) (v ?? 0).round()],
  );
});

final stepLogsProvider = FutureProvider.autoDispose<List<StepLog>>(
  (ref) => ref.watch(healthRepositoryProvider).steps(),
);

final mealLogsProvider = FutureProvider.autoDispose<List<MealLog>>(
  (ref) => ref.watch(healthRepositoryProvider).meals(),
);

final mealCaloriesProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(healthRepositoryProvider).mealCalories(),
);

void refreshStepMealData(WidgetRef ref) {
  ref
    ..invalidate(stepLogsProvider)
    ..invalidate(mealLogsProvider)
    ..invalidate(mealCaloriesProvider);
}

final goalsProvider = FutureProvider.autoDispose<List<Goal>>(
  (ref) => ref.watch(healthRepositoryProvider).goals(),
);

final medicationsProvider = FutureProvider.autoDispose<List<Medication>>(
  (ref) => ref.watch(healthRepositoryProvider).medications(),
);

final weightLogsProvider = FutureProvider.autoDispose<List<WeightLog>>(
  (ref) => ref.watch(healthRepositoryProvider).weights(limit: 10),
);

final waterLogsProvider = FutureProvider.autoDispose<List<WaterLog>>((ref) {
  final from = startOfDay(DateTime.now());
  return ref.watch(healthRepositoryProvider).water(from: from, limit: 20);
});

final sleepLogsProvider = FutureProvider.autoDispose<List<SleepLog>>(
  (ref) => ref.watch(healthRepositoryProvider).sleep(limit: 10),
);

/// Làm mới mọi dữ liệu hiển thị sau khi ghi thêm.
void refreshHealthData(WidgetRef ref) {
  ref
    ..invalidate(todaySummaryProvider)
    ..invalidate(bodyDataProvider)
    ..invalidate(goalsProvider)
    ..invalidate(medicationsProvider)
    ..invalidate(weightLogsProvider)
    ..invalidate(waterLogsProvider)
    ..invalidate(sleepLogsProvider);
}
