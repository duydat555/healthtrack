import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/metric_card.dart';
import 'health_providers.dart';

/// Sáu thẻ số liệu cơ thể (nước, giấc ngủ, bước chân, calories, cân nặng, BMI) dùng chung cho
/// Tổng quan và màn Chỉ số. [onOpen] nhận khóa biểu đồ xu hướng của thẻ được chạm.
List<MetricCard> bodyMetricCards(
  BuildContext context,
  BodyData data, {
  void Function(String metric)? onOpen,
}) {
  List<double> trend(Iterable<double> newestFirst) =>
      newestFirst.toList().reversed.take(7).toList();

  VoidCallback? open(String key) => onOpen == null ? null : () => onOpen(key);

  final weights = data.weights;
  final sleeps = data.sleeps;
  final steps = data.steps;
  final latestW = weights.firstOrNull;
  final prevW = weights.length > 1 ? weights[1] : null;
  final bmi = weights.map((w) => w.bmi).whereType<double>().firstOrNull;
  final latestSleep = sleeps.firstOrNull;
  final latestSteps = steps.firstOrNull;
  final todayWater = data.waterByDay.lastOrNull ?? 0;

  String weightCaption() {
    if (latestW == null) return 'Chưa có dữ liệu, bấm + để ghi';
    if (prevW == null) return 'Lần ghi đầu tiên';
    final d = latestW.weightKg - prevW.weightKg;
    if (d.abs() < 0.05) return 'Không đổi so với lần trước';
    return '${d < 0 ? 'Giảm' : 'Tăng'} ${formatNumber(d.abs())} kg so với lần trước';
  }

  return [
    MetricCard(
      onTap: open('water'),
      title: 'Nước uống',
      icon: Icons.water_drop,
      color: context.colors.water,
      value: formatNumber(todayWater / 1000),
      unit: 'lít',
      caption: 'Hôm nay',
      trend: [for (final v in data.waterByDay) v / 1000],
    ),
    MetricCard(
      onTap: open('sleep'),
      title: 'Giấc ngủ',
      icon: Icons.bedtime,
      color: context.colors.sleep,
      value: latestSleep == null
          ? '--'
          : formatNumber(latestSleep.durationMinutes / 60),
      unit: 'giờ',
      caption: latestSleep == null
          ? 'Chưa có dữ liệu'
          : 'Dậy lúc ${formatTime(latestSleep.endAt)}',
      trend: trend(sleeps.map((s) => s.durationMinutes / 60)),
    ),
    MetricCard(
      onTap: open('steps'),
      title: 'Bước chân',
      icon: Icons.directions_walk,
      color: context.colors.steps,
      value: latestSteps == null
          ? '--'
          : formatNumber(latestSteps.steps, digits: 0),
      unit: 'bước',
      caption: latestSteps == null
          ? 'Chưa có dữ liệu'
          : 'Ngày ${latestSteps.day}',
      trend: trend(steps.map((s) => s.steps.toDouble())),
    ),
    MetricCard(
      onTap: open('calories'),
      title: 'Calories',
      icon: Icons.local_fire_department,
      color: context.colors.meal,
      value: formatNumber(data.todayCalories, digits: 0),
      unit: 'kcal',
      caption: 'Hôm nay',
      trend: [data.todayCalories.toDouble()],
    ),
    MetricCard(
      onTap: open('weight'),
      title: 'Cân nặng',
      icon: Icons.monitor_weight,
      color: context.colors.weight,
      value: latestW == null ? '--' : formatNumber(latestW.weightKg),
      unit: 'kg',
      caption: weightCaption(),
      trend: trend(weights.map((w) => w.weightKg)),
    ),
    MetricCard(
      onTap: open('weight'),
      title: 'BMI',
      icon: Icons.accessibility_new,
      color: context.colors.medicine,
      value: bmi == null ? '--' : formatNumber(bmi),
      unit: '',
      caption: bmi == null ? 'Cần chiều cao trong Hồ sơ' : bmiLabel(bmi),
      trend: trend(weights.map((w) => w.bmi).whereType<double>()),
    ),
  ];
}
