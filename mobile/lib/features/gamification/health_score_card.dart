import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/confetti_burst.dart';
import '../../widgets/core_widgets.dart';
import '../../widgets/count_up.dart';
import '../health/health_providers.dart';
import 'models.dart';

/// Thẻ Health Score trên Tổng quan: điểm hôm nay, chuỗi ngày, thử thách tuần và lối vào Huy hiệu.
class HealthScoreCard extends ConsumerStatefulWidget {
  const HealthScoreCard({super.key});

  @override
  ConsumerState<HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends ConsumerState<HealthScoreCard> {
  bool _celebrated = false;

  void _celebrate(GamificationSummary s) {
    if (_celebrated || s.newAchievements.isEmpty) return;
    _celebrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final n = s.newAchievements.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn vừa đạt $n huy hiệu mới'),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => context.push('/achievements'),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gamificationProvider);
    return async.when(
      data: (s) {
        _celebrate(s);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _Body(summary: s),
            if (s.newAchievements.isNotEmpty)
              const Positioned.fill(child: ConfettiBurst()),
          ],
        );
      },
      loading: () =>
          const LoadingState(height: 128, label: 'Đang tải điểm sức khỏe'),
      error: (e, _) => ErrorState(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(gamificationProvider),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});

  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = summary;
    final ch = s.challenge;
    return Semantics(
      container: true,
      button: true,
      label:
          'Điểm sức khỏe hôm nay ${s.score} trên 100. Chuỗi ${s.streak} ngày liền. '
          '${ch.title}: ${ch.progress} trên ${ch.target}. Bấm để xem huy hiệu.',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card + 4),
          onTap: () => context.push('/achievements'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ActivityRings(
                  size: 92,
                  strokeWidth: 12,
                  rings: [RingData(color: c.steps, progress: s.score / 100)],
                  center: CountUp(
                    value: s.score.toDouble(),
                    style: AppFonts.number(28, color: c.ink),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Điểm sức khỏe',
                              style: AppTextStyles.cardTitle.copyWith(
                                color: c.ink,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: c.inkSoft),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: s.streak > 0 ? c.steps : c.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.streak > 0
                                ? '${s.streak} ngày liền'
                                : 'Chưa có chuỗi ngày',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ch.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ch.target == 0 ? 0 : ch.progress / ch.target,
                          minHeight: 6,
                          color: c.water,
                          backgroundColor: c.water.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
