import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:route_tracker/route_tracker.dart';

import '../../core/app_icons.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/core_widgets.dart';
import 'workout.dart';
import 'workout_history.dart';
import 'workout_math.dart' as wm;
import 'workout_repository.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  Sport? _sport;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Lịch sử hoạt động')),
        leading: RoundIconButton(
          size: 34,
          tooltip: 'Quay lại',
          symbol: 'chevron.left',
          icon: AppIcons.back,
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: history.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingState(label: 'Đang tải lịch sử hoạt động'),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ErrorState(
              message: 'Không tải được lịch sử hoạt động.',
              onRetry: () => ref.invalidate(workoutsProvider),
            ),
          ),
          data: (workouts) => _buildHistory(context, workouts),
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context, List<Workout> workouts) {
    final totals = workoutDistanceTotals(workouts, now: DateTime.now());
    final filtered = filterWorkouts(workouts, _sport);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: 1 + (filtered.isEmpty ? 1 : filtered.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Quãng đường', style: context.text.sectionTitle),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DistanceCard(
                      label: 'Tuần này',
                      meters: totals.weekM,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _DistanceCard(
                      label: 'Tháng này',
                      meters: totals.monthM,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text('Buổi tập', style: context.text.sectionTitle),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final sport in [null, ...Sport.values])
                    ChoiceChip(
                      label: Text(sport?.label ?? 'Tất cả'),
                      selected: _sport == sport,
                      onSelected: (_) => setState(() => _sport = sport),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          );
        }
        if (filtered.isEmpty) {
          return workouts.isEmpty
              ? EmptyState(
                  message: 'Bạn chưa có buổi tập nào.',
                  actionLabel: 'Ghi hoạt động',
                  onAction: () => context.push('/record'),
                )
              : const EmptyState(message: 'Chưa có buổi tập cho môn này.');
        }
        final workout = filtered[index - 1];
        return Padding(
          key: ValueKey(workout.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _WorkoutCard(workout: workout),
        );
      },
    );
  }
}

String _kilometers(double meters) =>
    '${formatNumber(meters / 1000, digits: 2)} km';

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.label, required this.meters});

  final String label;
  final double meters;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.secondary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _kilometers(meters),
          style: AppFonts.number(20, color: context.colors.ink),
        ),
      ],
    ),
  );
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final local = workout.startedAt.toLocal();
    final title = workout.title.trim().isEmpty
        ? defaultTitle(workout.sport, local)
        : workout.title;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () => context.push('/workout/${Uri.encodeComponent(workout.id)}'),
      child: Row(
        children: [
          _RouteThumbnail(workout: workout),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.cardTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${workout.sport.label} · ${local.day}/${local.month}/${local.year}',
                  style: context.text.caption,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${_kilometers(workout.distanceM)} · ${wm.formatDuration(workout.movingSeconds)}',
                  style: context.text.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Icon(AppIcons.chevron, size: 16, color: context.colors.inkSoft),
        ],
      ),
    );
  }
}

class _RouteThumbnail extends StatelessWidget {
  const _RouteThumbnail({required this.workout});

  final Workout workout;

  List<MapPoint> _routePoints() {
    if (workout.points.length >= 2) {
      return [
        for (final point in workout.points) MapPoint(point.lat, point.lon),
      ];
    }
    try {
      return [
        for (final (lat, lon) in wm.decodePolyline(workout.polyline))
          MapPoint(lat, lon),
      ];
    } on RangeError {
      // Polyline bị cắt ngắn không ngăn người dùng mở buổi tập.
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final points = _routePoints();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: SizedBox(
        width: 76,
        height: 64,
        child: points.length < 2
            ? Semantics(
                label: 'Không có lộ trình',
                child: ColoredBox(
                  color: colors.backgroundSecondary,
                  child: Icon(AppIcons.route, color: colors.inkSoft),
                ),
              )
            : Semantics(
                image: true,
                label: 'Bản đồ lộ trình thu nhỏ',
                child: CustomPaint(
                  painter: RoutePainter(
                    points: points,
                    background: colors.backgroundSecondary,
                    gradient: [colors.brandText],
                    lineWidth: 2,
                  ),
                ),
              ),
      ),
    );
  }
}
