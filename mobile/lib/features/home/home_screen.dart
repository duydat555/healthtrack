import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/theme.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/section_header.dart';

/// Màn Tổng quan, bố cục theo app Fitness của Apple.
/// Số liệu bên dưới là DỮ LIỆU MẪU để dựng giao diện; sẽ thay bằng API ở Phase 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Dữ liệu mẫu hôm nay: (đã đạt, mục tiêu)
  static const _steps = (6480.0, 10000.0);
  static const _sleep = (7.3, 8.0);
  static const _water = (1.2, 2.0);

  static const _weekSteps = [
    8200.0,
    10400.0,
    6100.0,
    9800.0,
    11200.0,
    7300.0,
    6480.0,
  ];
  static const _weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            LiquidGlassTabBar.height + 48,
          ),
          children: [
            const Text(
              'THỨ HAI, 9 THÁNG 11',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tổng quan',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SectionHeader('Hôm nay'),
            _RingsCard(steps: _steps, sleep: _sleep, water: _water),
            const SectionHeader('Chỉ số cơ thể'),
            const _MetricGrid(),
            const SectionHeader('7 ngày qua'),
            const _WeekChart(values: _weekSteps, labels: _weekDays),
          ],
        ),
      ),
    );
  }
}

class _RingsCard extends StatelessWidget {
  const _RingsCard({
    required this.steps,
    required this.sleep,
    required this.water,
  });

  final (double, double) steps;
  final (double, double) sleep;
  final (double, double) water;

  @override
  Widget build(BuildContext context) {
    double p((double, double) v) => v.$1 / v.$2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            ActivityRings(
              size: 124,
              strokeWidth: 16,
              rings: [
                RingData(color: AppColors.steps, progress: p(steps)),
                RingData(color: AppColors.sleep, progress: p(sleep)),
                RingData(color: AppColors.water, progress: p(water)),
              ],
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    'Bước chân',
                    '6.480',
                    '/10.000',
                    'BƯỚC',
                    AppColors.steps,
                  ),
                  const SizedBox(height: 12),
                  _Legend('Giấc ngủ', '7,3', '/8', 'GIỜ', AppColors.sleep),
                  const SizedBox(height: 12),
                  _Legend('Nước uống', '1,2', '/2', 'LÍT', AppColors.water),
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
  const _Legend(this.label, this.value, this.goal, this.unit, this.color);

  final String label;
  final String value;
  final String goal;
  final String unit;
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
                text: '$goal $unit',
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
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    const cards = [
      MetricCard(
        title: 'Cân nặng',
        icon: Icons.monitor_weight,
        color: AppColors.weight,
        value: '68,4',
        unit: 'kg',
        caption: 'Giảm 0,6 kg tuần này',
        trend: [69.4, 69.2, 69.0, 68.9, 68.7, 68.6, 68.4],
      ),
      MetricCard(
        title: 'BMI',
        icon: Icons.accessibility_new,
        color: AppColors.medicine,
        value: '22,1',
        unit: '',
        caption: 'Bình thường',
        trend: [22.4, 22.4, 22.3, 22.3, 22.2, 22.2, 22.1],
      ),
      MetricCard(
        title: 'Bữa ăn',
        icon: Icons.restaurant,
        color: AppColors.meal,
        value: '1.850',
        unit: 'kcal',
        caption: 'Còn 350 kcal',
        trend: [2100, 1900, 2050, 1700, 2200, 1950, 1850],
      ),
      MetricCard(
        title: 'Thuốc',
        icon: Icons.medication,
        color: AppColors.sleep,
        value: '2/3',
        unit: 'liều',
        caption: 'Liều kế tiếp 21:00',
        trend: [3, 3, 2, 3, 3, 3, 2],
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

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final max = values.reduce((a, b) => a > b ? a : b);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bước chân',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.steps,
              ),
            ),
            const SizedBox(height: 2),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '8.511',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' bước/ngày',
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
                                    ? AppColors.steps
                                    : AppColors.steps.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
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
