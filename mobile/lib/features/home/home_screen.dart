import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/count_up.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_controller.dart';
import '../coach/weekly_insight_card.dart';
import '../gamification/health_score_card.dart';
import '../health/health_providers.dart';
import '../health/healthkit_sync.dart';
import '../../widgets/core_widgets.dart';

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
          color: context.colors.brand,
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
              const _AutoSync(),
              Text(
                formatHeaderDate(DateTime.now()),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Tổng quan',
                        style: AppTextStyles.pageTitle.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hỏi Coach',
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: context.colors.inkSoft,
                    ),
                    onPressed: () => context.push('/coach'),
                  ),
                  if (user != null)
                    Semantics(
                      label: 'Hồ sơ của ${user.fullName}',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: context.colors.cardHigh,
                        child: Text(
                          user.initial,
                          style: AppFonts.number(18, color: context.colors.ink),
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
              const SizedBox(height: 12),
              const HealthScoreCard(),
              const WeeklyInsightCard(),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              SectionHeader(
                '7 ngày qua',
                onTap: () => context.push('/trends?metric=water'),
              ),
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

/// Thẻ phẳng theo quy chuẩn docs/05: Liquid Glass chỉ dành cho lớp nổi, không phủ lên nội dung cuộn.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.accent});

  final Widget child;

  /// Màu tạo vầng sáng rất nhẹ ở góc trên bên trái, để thẻ chính có chiều sâu mà không cần bóng.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        gradient: accent == null
            ? null
            : RadialGradient(
                center: const Alignment(-0.85, -0.9),
                radius: 1.3,
                colors: [
                  accent!.withValues(alpha: c.isDark ? 0.16 : 0.1),
                  c.card,
                ],
              ),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
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
        accent: context.colors.water,
        child: Row(
          children: [
            ActivityRings(
              size: 128,
              strokeWidth: 15,
              center: CountUp(
                value:
                    (s.waterProgress.clamp(0.0, 1.0) +
                        s.sleepProgress.clamp(0.0, 1.0) +
                        s.medsProgress.clamp(0.0, 1.0)) /
                    3 *
                    100,
                format: (v) => '${v.round()}%',
                style: AppFonts.number(24, color: context.colors.ink),
              ),
              rings: [
                RingData(
                  color: context.colors.water,
                  progress: s.waterProgress,
                ),
                RingData(
                  color: context.colors.sleep,
                  progress: s.sleepProgress,
                ),
                RingData(color: context.colors.meds, progress: s.medsProgress),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    'Nước uống',
                    formatNumber(s.waterMl / 1000),
                    '/${formatNumber(s.waterGoalMl / 1000)} lít',
                    context.colors.water,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    'Giấc ngủ',
                    s.sleepMinutes == null
                        ? '--'
                        : formatNumber(s.sleepMinutes! / 60),
                    '/${formatNumber(s.sleepGoalMinutes / 60)} giờ',
                    context.colors.sleep,
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    'Thuốc',
                    '${s.medsTaken}',
                    '/${s.medsTotal} liều',
                    context.colors.meds,
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
    final c = context.colors;
    final number = double.tryParse(value.replaceAll(',', '.'));
    final style = AppFonts.number(26, color: c.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (number == null)
                Text(value, style: style)
              else
                CountUp(
                  value: number,
                  style: style,
                  format: (v) => formatNumber(v),
                ),
              const SizedBox(width: 3),
              Text(
                goal,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.inkSoft,
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
        color: context.colors.water,
        value: formatNumber(todayWater / 1000),
        unit: 'lít',
        caption: 'Hôm nay',
        trend: [for (final v in data.waterByDay) v / 1000],
      ),
      MetricCard(
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
        trend: _trend(sleeps.map((s) => s.durationMinutes / 60)),
      ),
      MetricCard(
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
        trend: _trend(steps.map((s) => s.steps.toDouble())),
      ),
      MetricCard(
        title: 'Calories',
        icon: Icons.local_fire_department,
        color: context.colors.meal,
        value: formatNumber(data.todayCalories, digits: 0),
        unit: 'kcal',
        caption: 'Hôm nay',
        trend: [data.todayCalories.toDouble()],
      ),
      MetricCard(
        title: 'Cân nặng',
        icon: Icons.monitor_weight,
        color: context.colors.weight,
        value: latestW == null ? '--' : formatNumber(latestW.weightKg),
        unit: 'kg',
        caption: weightCaption(),
        trend: _trend(weights.map((w) => w.weightKg)),
      ),
      MetricCard(
        title: 'BMI',
        icon: Icons.accessibility_new,
        color: context.colors.medicine,
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
            Text(
              'Nước uống',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.water,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatNumber(total / 7 / 1000),
                    style: AppFonts.number(30, color: context.colors.ink),
                  ),
                  TextSpan(
                    text: ' lít/ngày',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.inkSoft,
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
                              duration: AppMotion.of(
                                context,
                                Duration(milliseconds: 500 + i * 80),
                              ),
                              curve: AppMotion.curve,
                              builder: (context, t, _) => Container(
                                height: 88 * t,
                                width: 18,
                                decoration: BoxDecoration(
                                  gradient: i == values.length - 1
                                      ? context.colors.water.gradient
                                      : null,
                                  color: i == values.length - 1
                                      ? null
                                      : context.colors.water.withValues(
                                          alpha: 0.38,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label(i),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.inkSoft,
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

/// Đồng bộ Apple Health một lần khi mở Tổng quan (nếu người dùng đã bật).
class _AutoSync extends ConsumerStatefulWidget {
  const _AutoSync();

  @override
  ConsumerState<_AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<_AutoSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(healthSyncProvider.notifier).syncIfEnabled();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
