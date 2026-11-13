import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/core_widgets.dart';
import '../health/health_providers.dart';
import 'models.dart';

/// Lưới huy hiệu. Huy hiệu chưa đạt hiện mờ kèm điều kiện để đạt.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  static const _icons = <String, IconData>{
    'first_log': Icons.flag_rounded,
    'streak_3': Icons.local_fire_department,
    'streak_7': Icons.whatshot,
    'streak_30': Icons.workspace_premium,
    'water_goal': Icons.water_drop,
    'sleep_goal': Icons.bedtime,
    'steps_10k': Icons.directions_walk,
    'perfect_day': Icons.auto_awesome,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(achievementsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Semantics(
          header: true,
          child: Text(
            'Huy hiệu',
            style: AppTextStyles.sectionTitle.copyWith(color: c.ink),
          ),
        ),
      ),
      body: SafeArea(
        child: async.when(
          data: (items) => _Grid(items: items),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingState(height: 240, label: 'Đang tải huy hiệu'),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorState(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(achievementsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<Achievement> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = items.where((a) => a.earned).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Đã đạt $done trên ${items.length}',
          style: TextStyle(fontSize: 15, color: c.inkSoft),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final a in items)
                  SizedBox(
                    width: w,
                    child: _Badge(item: a),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.item});

  final Achievement item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = c.steps;
    final earned = item.earned;
    return Semantics(
      label:
          '${item.title}. ${item.description}. ${earned ? 'Đã đạt' : 'Chưa đạt'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: earned ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: earned ? accent.gradient : null,
                    color: earned ? null : c.cardHigh,
                    shape: BoxShape.circle,
                    boxShadow: earned && c.isDark ? accent.glow : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      AchievementsScreen._icons[item.code] ?? Icons.star,
                      color: earned ? Colors.white : c.inkSoft,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: AppTextStyles.cardTitle.copyWith(color: c.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 13, color: c.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
