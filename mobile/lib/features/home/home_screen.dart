import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_controller.dart';
import '../health/health_providers.dart';
import 'dashboard_states.dart';

/// Màn Tổng quan (Dashboard), bố cục theo app Fitness của Apple, dữ liệu lấy từ backend.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final summary = ref.watch(todaySummaryProvider);
    final body = ref.watch(bodyDataProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            refreshHealthData(ref);
            refreshStepMealData(ref);
            await Future.wait<Object?>([
              ref
                  .read(todaySummaryProvider.future)
                  .then<Object?>((v) => v, onError: (_) => _empty),
              ref
                  .read(bodyDataProvider.future)
                  .then<Object?>((v) => v, onError: (_) => null),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              LiquidGlassTabBar.height + 48,
            ),
            children: [
              Text(
                formatHeaderDate(DateTime.now()),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Tổng quan',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  if (user != null)
                    Semantics(
                      label: 'Hồ sơ của ${user.fullName}',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.cardHigh,
                        child: Text(
                          user.initial,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SectionHeader('Hôm nay'),
              summary.when(
                data: (s) => _RingsCard(summary: s),
                loading: () => const LoadingState(
                  height: 172,
                  label: 'Đang tải tóm tắt hôm nay',
                ),
                error: (e, _) => ErrorState(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(todaySummaryProvider),
                ),
              ),
              const SectionHeader('Chỉ số cơ thể'),
              body.when(
                data: (b) => b.isEmpty
                    ? EmptyState(
                        message: 'Chưa có dữ liệu sức khỏe nào. Bấm + để ghi nhận nước, giấc ngủ, bước chân, bữa ăn hoặc cân nặng.',
                        actionLabel: 'Ghi dữ liệu ngay',
                        onAction: () => context.push('/add'),
                      )
                    : _MetricGrid(data: b),
                loading: () => const LoadingState(
                  height: 220,
                  label: 'Đang tải chỉ số cơ thể',
                ),
                error: (e, _) => ErrorState(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(bodyDataProvider),
                ),
              ),
              const SectionHeader('7 ngày qua'),
              body.when(
                data: (b) => _WaterWeekChart(values: b.waterByDay),
                loading: () => const LoadingState(
                  height: 220,
                  label: 'Đang tải biểu đồ nước 7 ngày qua',
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _empty = TodaySummary(
  waterMl: 0,
  waterGoalMl: defaultWaterGoalMl,
  sleepMinutes: null,
  sleepGoalMinutes: defaultSleepGoalMinutes,
  medsTaken: 0,
  medsTotal: 0,
);

/// Lớp bọc LiquidGlass nền tối giúp chữ và biểu tượng luôn đạt tương phản cao.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      cornerRadius: AppRadius.card,
      tint: AppColors.card,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

class _RingsCard extends StatelessWidget {
  const _RingsCard({required this.summary});

  final TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final sleepDesc = s.sleepMinutes == null
        ? 'chưa có dữ liệu'
        : '${formatNumber(s.sleepMinutes! / 60)} trên ${formatNumber(s.sleepGoalMinutes / 60)} giờ';
    return Semantics(
      container: true,
      label:
          'Tóm tắt hôm nay: Nước uống ${formatNumber(s.waterMl / 1000)} trên ${formatNumber(s.waterGoalMl / 1000)} lít, Giấc ngủ $sleepDesc, Thuốc ${s.medsTaken} trên ${s.medsTotal} liều.',
      child: _GlassCard(
        child: Row(
          children: [
            ActivityRings(
              size: 124,
              strokeWidth: 16,
              rings: [
                RingData(color: AppColors.water, progress: s.waterProgress),
                RingData(color: AppColors.sleep, progress: s.sleepProgress),
                RingData(color: AppColors.meds, progress: s.medsProgress),
              ],
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    'Nước uống',
                    formatNumber(s.waterMl / 1000),
                    '/${formatNumber(s.waterGoalMl / 1000)} LÍT',
                    AppColors.water,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    'Giấc ngủ',
                    s.sleepMinutes == null
                        ? '--'
                        : formatNumber(s.sleepMinutes! / 60),
                    '/${formatNumber(s.sleepGoalMinutes / 60)} GIỜ',
                    AppColors.sleep,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    'Thuốc',
                    '${s.medsTaken}',
                    '/${s.medsTotal} LIỀU',
                    AppColors.meds,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.goal, this.color);

  final String label;
  final String value;
  final String goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: goal,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});

  final BodyData data;

  List<double> _trend(Iterable<double> newestFirst) =>
      newestFirst.toList().reversed.take(7).toList();

  @override
  Widget build(BuildContext context) {
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

    final cards = [
      MetricCard(
        title: 'Nước uống',
        icon: Icons.water_drop,
        color: AppColors.water,
        value: formatNumber(todayWater / 1000),
        unit: 'lít',
        caption: 'Hôm nay',
        trend: [for (final v in data.waterByDay) v / 1000],
      ),
      MetricCard(
        title: 'Giấc ngủ',
        icon: Icons.bedtime,
        color: AppColors.sleep,
        value: latestSleep == null
            ? '--'
            : formatNumber(latestSleep.durationMinutes / 60),
        unit: 'giờ',
        caption: latestSleep == null
            ? 'Chưa có dữ liệu'
            : 'Dậy lúc ${formatTime(latestSleep.endAt)}',
        trend: _trend(sleeps.map((s) => s.durationMinutes / 60)),
      ),
      MetricCard(
        title: 'Bước chân',
        icon: Icons.directions_walk,
        color: AppColors.steps,
        value: latestSteps == null
            ? '--'
            : formatNumber(latestSteps.steps, digits: 0),
        unit: 'bước',
        caption: latestSteps == null
            ? 'Chưa có dữ liệu'
            : 'Ngày ${latestSteps.day}',
        trend: _trend(steps.map((s) => s.steps.toDouble())),
      ),
      MetricCard(
        title: 'Calories',
        icon: Icons.local_fire_department,
        color: AppColors.meal,
        value: formatNumber(data.todayCalories, digits: 0),
        unit: 'kcal',
        caption: 'Hôm nay',
        trend: [data.todayCalories.toDouble()],
      ),
      MetricCard(
        title: 'Cân nặng',
        icon: Icons.monitor_weight,
        color: AppColors.weight,
        value: latestW == null ? '--' : formatNumber(latestW.weightKg),
        unit: 'kg',
        caption: weightCaption(),
        trend: _trend(weights.map((w) => w.weightKg)),
      ),
      MetricCard(
        title: 'BMI',
        icon: Icons.accessibility_new,
        color: AppColors.medicine,
        value: bmi == null ? '--' : formatNumber(bmi),
        unit: '',
        caption: bmi == null ? 'Cần chiều cao trong Hồ sơ' : bmiLabel(bmi),
        trend: _trend(weights.map((w) => w.bmi).whereType<double>()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

class _WaterWeekChart extends StatelessWidget {
  const _WaterWeekChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(1, (a, b) => b > a ? b : a);
    final total = values.fold<int>(0, (a, b) => a + b);
    final now = DateTime.now();
    // Ngày của cột i: hôm nay là cột cuối
    String label(int i) =>
        weekdayShort[now.subtract(Duration(days: 6 - i)).weekday - 1];

    if (values.isEmpty || total == 0) {
      return const EmptyState(
        icon: Icons.water_drop_outlined,
        message: 'Chưa có dữ liệu nước uống trong 7 ngày qua.',
      );
    }

    return Semantics(
      container: true,
      label:
          'Biểu đồ nước uống 7 ngày qua, trung bình ${formatNumber(total / 7 / 1000)} lít mỗi ngày',
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nước uống',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.water,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatNumber(total / 7 / 1000),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const TextSpan(
                    text: ' lít/ngày',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Semantics(
                        label:
                            '${label(i)}: ${formatNumber(values[i] / 1000)} lít',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: values[i] / max),
                              duration: Duration(milliseconds: 500 + i * 80),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, _) => Container(
                                height: 88 * t,
                                width: 18,
                                decoration: BoxDecoration(
                                  color: i == values.length - 1
                                      ? AppColors.water
                                      : AppColors.water.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label(i),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
