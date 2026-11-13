import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/count_up.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_controller.dart';
import '../coach/weekly_insight_card.dart';
import '../gamification/health_score_card.dart';
import '../health/health_providers.dart';
import '../health/metric_cards.dart';
import '../health/healthkit_sync.dart';
import '../widget/widget_sync.dart';
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
          color: context.colors.brandText,
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
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppLayout.tabBarInset(context),
            ),
            children: [
              const _AutoSync(),
              const WidgetSync(),
              Text(
                formatHeaderDate(DateTime.now()).toUpperCase(),
                style: context.text.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Tổng quan', style: context.text.largeTitle),
                    ),
                  ),
                  RoundIconButton(
                    tooltip: 'Hỏi Coach',
                    icon: Icons.chat_bubble_outline,
                    onTap: () => context.push('/coach'),
                  ),
                  if (user != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Semantics(
                      label: 'Hồ sơ của ${user.fullName}',
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: context.colors.brand,
                        child: Text(
                          user.initial,
                          style: AppFonts.number(
                            17,
                            color: context.colors.onBrand,
                          ),
                        ),
                      ),
                    ),
                  ],
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
              const SizedBox(height: AppSpacing.sm),
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
                actionLabel: 'Xem tất cả',
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
      child: AppCard(
        child: Row(
          children: [
            ActivityRings(
              size: 120,
              strokeWidth: 13,
              center: CountUp(
                value:
                    (s.waterProgress.clamp(0.0, 1.0) +
                        s.sleepProgress.clamp(0.0, 1.0) +
                        s.medsProgress.clamp(0.0, 1.0)) /
                    3 *
                    100,
                format: (v) => '${v.round()}%',
                style: AppFonts.number(22, color: context.colors.ink),
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
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    'Nước uống',
                    formatNumber(s.waterMl / 1000),
                    '/${formatNumber(s.waterGoalMl / 1000)} lít',
                    context.colors.water,
                    s.waterProgress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Legend(
                    'Giấc ngủ',
                    s.sleepMinutes == null
                        ? '--'
                        : formatNumber(s.sleepMinutes! / 60),
                    '/${formatNumber(s.sleepGoalMinutes / 60)} giờ',
                    context.colors.sleep,
                    s.sleepProgress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Legend(
                    'Thuốc',
                    '${s.medsTaken}',
                    '/${s.medsTotal} liều',
                    context.colors.meds,
                    s.medsProgress,
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

/// Một dòng chú giải của vòng: tên và phần trăm (chữ, không chỉ màu), giá trị màu danh mục kèm mục tiêu.
class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.goal, this.color, this.progress);

  final String label;
  final String value;
  final String goal;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final number = double.tryParse(value.replaceAll(',', '.'));
    final style = AppFonts.number(24, color: color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · ${(progress * 100).round()}%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xxs / 2),
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
                style: context.text.secondary.copyWith(
                  fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final cards = bodyMetricCards(
      context,
      data,
      onOpen: (metric) => context.push('/trends?metric=$metric'),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nước uống',
              style: context.text.cardTitle.copyWith(
                color: context.colors.water,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatNumber(total / 7 / 1000),
                    style: AppFonts.number(30, color: context.colors.ink),
                  ),
                  TextSpan(
                    text: ' lít/ngày',
                    style: context.text.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                            const SizedBox(height: AppSpacing.xs),
                            Text(label(i), style: context.text.caption),
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
