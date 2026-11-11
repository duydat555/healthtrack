import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../health/health_providers.dart';

/// Màn Chỉ số: các thẻ Liquid Glass (chạm để mở rộng, hiệu ứng morph) với số liệu thật.
class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(bodyDataProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chỉ số',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Xem biểu đồ xu hướng',
                    child: IconButton(
                      tooltip: 'Xem biểu đồ xu hướng',
                      onPressed: () => context.push('/trends'),
                      icon: const Icon(
                        Icons.show_chart_rounded,
                        color: AppColors.ink,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: body.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          apiErrorMessage(e),
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(bodyDataProvider),
                          child: const Text(
                            'Thử lại',
                            style: TextStyle(color: AppColors.brand),
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (b) {
                    final w = b.weights.firstOrNull;
                    final s = b.sleeps.firstOrNull;
                    final avgSleep = b.sleeps.isEmpty
                        ? null
                        : b.sleeps.fold<int>(
                                0,
                                (a, e) => a + e.durationMinutes,
                              ) ~/
                              b.sleeps.length;
                    final cards = [
                      GlassCardData(
                        id: 'water',
                        title: 'Nước uống',
                        subtitle:
                            '${formatNumber(b.waterByDay.last / 1000)} lít hôm nay',
                        detail:
                            'Trung bình ${formatNumber(b.waterByDay.fold<int>(0, (a, e) => a + e) / 7000)} lít mỗi ngày trong 7 ngày qua.',
                        symbol: 'drop.fill',
                        icon: Icons.water_drop,
                      ),
                      GlassCardData(
                        id: 'sleep',
                        title: 'Giấc ngủ',
                        subtitle: s == null
                            ? 'Chưa có dữ liệu'
                            : formatDuration(s.durationMinutes),
                        detail: avgSleep == null
                            ? 'Ghi giấc ngủ bằng nút + để xem thống kê.'
                            : 'Trung bình ${formatDuration(avgSleep)} mỗi đêm qua ${b.sleeps.length} lần ghi gần nhất.',
                        symbol: 'bed.double.fill',
                        icon: Icons.bedtime,
                      ),
                      GlassCardData(
                        id: 'weight',
                        title: 'Cân nặng',
                        subtitle: w == null
                            ? 'Chưa có dữ liệu'
                            : '${formatNumber(w.weightKg)} kg',
                        detail: w == null
                            ? 'Ghi cân nặng bằng nút + để theo dõi xu hướng.'
                            : w.bmi == null
                            ? 'Thêm chiều cao trong Hồ sơ để tính BMI.'
                            : 'BMI ${formatNumber(w.bmi!)}: ${bmiLabel(w.bmi!)}.',
                        symbol: 'scalemass.fill',
                        icon: Icons.monitor_weight,
                      ),
                    ];
                    return LayoutBuilder(
                      // Nội dung thẻ do native vẽ nên dựng lại view khi số liệu đổi
                      key: ValueKey(
                        cards.map((c) => '${c.subtitle}|${c.detail}').join('#'),
                      ),
                      builder: (context, c) => LiquidGlassCardGroup(
                        cards: cards,
                        height: c.maxHeight,
                        dark: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: LiquidGlassTabBar.height + 24),
            ],
          ),
        ),
      ),
    );
  }
}
