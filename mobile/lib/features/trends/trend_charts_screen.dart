import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/section_header.dart';
import '../health/health_providers.dart';
import '../health/models.dart';

/// Metadata hiển thị và quy đổi đơn vị cho từng chỉ số xu hướng.
class _MetricMeta {
  const _MetricMeta({
    required this.key,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.isBarChart,
    this.divisor = 1,
    this.digits = 1,
  });

  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isBarChart;
  final double divisor;
  final int digits;

  double convert(double raw) => raw / divisor;
}

const _metricMetas = [
  _MetricMeta(
    key: 'water',
    label: 'Nước uống',
    unit: 'lít',
    icon: Icons.water_drop,
    color: AppColors.water,
    isBarChart: true,
    divisor: 1000,
    digits: 1,
  ),
  _MetricMeta(
    key: 'steps',
    label: 'Bước chân',
    unit: 'bước',
    icon: Icons.directions_walk,
    color: AppColors.steps,
    isBarChart: true,
    divisor: 1,
    digits: 0,
  ),
  _MetricMeta(
    key: 'sleep',
    label: 'Giấc ngủ',
    unit: 'giờ',
    icon: Icons.bedtime,
    color: AppColors.sleep,
    isBarChart: false,
    divisor: 60,
    digits: 1,
  ),
  _MetricMeta(
    key: 'weight',
    label: 'Cân nặng',
    unit: 'kg',
    icon: Icons.monitor_weight,
    color: AppColors.weight,
    isBarChart: false,
    divisor: 1,
    digits: 1,
  ),
  _MetricMeta(
    key: 'calories',
    label: 'Calories',
    unit: 'kcal',
    icon: Icons.local_fire_department,
    color: AppColors.meal,
    isBarChart: true,
    divisor: 1,
    digits: 0,
  ),
];

const _ranges = <String, String>{
  '7d': '7 ngày',
  '30d': '30 ngày',
  '90d': '90 ngày',
};

/// Màn hình Biểu đồ xu hướng: xem theo 7 / 30 / 90 ngày với fl_chart và touch tooltip.
class TrendChartsScreen extends ConsumerStatefulWidget {
  const TrendChartsScreen({super.key, this.initialMetric = 'water'});

  final String initialMetric;

  @override
  ConsumerState<TrendChartsScreen> createState() => _TrendChartsScreenState();
}

class _TrendChartsScreenState extends ConsumerState<TrendChartsScreen> {
  late String _metric;
  String _range = '7d';
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _metric = _metricMetas.any((m) => m.key == widget.initialMetric)
        ? widget.initialMetric
        : 'water';
  }

  _MetricMeta get _currentMeta =>
      _metricMetas.firstWhere((m) => m.key == _metric);

  @override
  Widget build(BuildContext context) {
    final query = (metric: _metric, range: _range);
    final trend = ref.watch(trendSeriesProvider(query));
    final meta = _currentMeta;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Semantics(
          header: true,
          child: Text(
            'Xu hướng',
            style: TextStyle(
              color: context.colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.brand,
          onRefresh: () async {
            ref.invalidate(trendSeriesProvider(query));
            await ref
                .read(trendSeriesProvider(query).future)
                .catchError(
                  (_) => TrendSeries(
                    metric: _metric,
                    unit: '',
                    range: _range,
                    points: const [],
                  ),
                );
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Bộ chọn chỉ số
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in _metricMetas)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          selected: m.key == _metric,
                          label: 'Xem xu hướng ${m.label}',
                          child: ChoiceChip(
                            label: Text(m.label),
                            avatar: Icon(
                              m.icon,
                              color: context.colors.adapt(m.color),
                              size: 18,
                            ),
                            selected: m.key == _metric,
                            selectedColor: context.colors
                                .adapt(m.color)
                                .withValues(alpha: 0.24),
                            backgroundColor: context.colors.card,
                            labelStyle: TextStyle(
                              color: context.colors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() {
                              _metric = m.key;
                              _touchedIndex = null;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Segmented Control 7 / 30 / 90 ngày
              Semantics(
                label: 'Chọn khoảng thời gian xem xu hướng',
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    backgroundColor: context.colors.card,
                    thumbColor: context.colors.cardHigh,
                    groupValue: _range,
                    onValueChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _range = value;
                        _touchedIndex = null;
                      });
                    },
                    children: {
                      for (final e in _ranges.entries)
                        e.key: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Semantics(
                            button: true,
                            selected: _range == e.key,
                            label: 'Khoảng thời gian ${e.value}',
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _range == e.key
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _range == e.key
                                    ? context.colors.ink
                                    : context.colors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              trend.when(
                loading: () => const _TrendLoading(),
                error: (e, _) => _TrendError(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(trendSeriesProvider(query)),
                ),
                data: (series) {
                  final hasAnyData = series.points.any((p) => p.value != null);
                  if (series.points.isEmpty || !hasAnyData) {
                    return _TrendEmpty(
                      metricLabel: meta.label,
                      rangeLabel: _ranges[_range] ?? _range,
                      icon: meta.icon,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TrendChartCard(
                        meta: meta,
                        series: series,
                        touchedIndex: _touchedIndex,
                        onTouchIndex: (i) {
                          if (_touchedIndex != i) {
                            setState(() => _touchedIndex = i);
                          }
                        },
                      ),
                      const SectionHeader('Tóm tắt'),
                      _TrendStatsRow(meta: meta, points: series.points),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.meta,
    required this.series,
    required this.touchedIndex,
    required this.onTouchIndex,
  });

  final _MetricMeta meta;
  final TrendSeries series;
  final int? touchedIndex;
  final ValueChanged<int?> onTouchIndex;

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final points = series.points;
    final nonNullValues = [
      for (final p in points)
        if (p.value != null) meta.convert(p.value!),
    ];
    final avg = nonNullValues.isEmpty
        ? 0.0
        : nonNullValues.reduce((a, b) => a + b) / nonNullValues.length;
    final touched =
        touchedIndex != null &&
            touchedIndex! >= 0 &&
            touchedIndex! < points.length
        ? points[touchedIndex!]
        : null;
    final touchedText = touched == null
        ? 'Trung bình: ${formatNumber(avg, digits: meta.digits)} ${meta.unit}'
        : touched.value == null
        ? '${_shortDate(touched.date)}: Chưa có dữ liệu'
        : '${_shortDate(touched.date)}: ${formatNumber(meta.convert(touched.value!), digits: meta.digits)} ${meta.unit}';

    return Semantics(
      container: true,
      label:
          'Biểu đồ xu hướng ${meta.label} trong ${_ranges[series.range] ?? series.range}. Trung bình ${formatNumber(avg, digits: meta.digits)} ${meta.unit}. Chạm vào từng cột hoặc điểm để xem chi tiết.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    meta.icon,
                    color: context.colors.adapt(meta.color),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    meta.label,
                    style: TextStyle(
                      color: context.colors.adapt(meta.color),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _ranges[series.range] ?? series.range,
                    style: TextStyle(
                      color: context.colors.inkSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                touchedText,
                style: TextStyle(
                  color: context.colors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 230,
                child: meta.isBarChart
                    ? _buildBarChart(context, points)
                    : _buildLineChart(context, points),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _stepInterval(int len) {
    if (len <= 7) return 1;
    if (len <= 30) return 5;
    return 15;
  }

  Widget _buildBarChart(BuildContext context, List<TrendPoint> points) {
    final values = [
      for (final p in points) p.value == null ? 0.0 : meta.convert(p.value!),
    ];
    final maxVal = values.fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = maxVal <= 0 ? 10.0 : maxVal * 1.25;
    final interval = _stepInterval(points.length);
    final rodWidth = points.length <= 7
        ? 18.0
        : (points.length <= 30 ? 6.0 : 2.5);

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: context.colors.separator, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  formatNumber(value, digits: meta.digits),
                  style: TextStyle(color: context.colors.inkSoft, fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i < 0 ||
                    i >= points.length ||
                    (i % interval.round()) != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortDate(points[i].date),
                    style: TextStyle(
                      color: context.colors.inkSoft,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              return;
            }
            onTouchIndex(response.spot!.touchedBarGroupIndex);
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.cardHigh,
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x];
              final valText = p.value == null
                  ? 'Chưa có dữ liệu'
                  : '${formatNumber(meta.convert(p.value!), digits: meta.digits)} ${meta.unit}';
              return BarTooltipItem(
                '${_shortDate(p.date)}\n$valText',
                TextStyle(
                  color: context.colors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: rodWidth,
                  color: touchedIndex == i
                      ? context.colors.adapt(meta.color)
                      : context.colors
                            .adapt(meta.color)
                            .withValues(alpha: 0.78),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, List<TrendPoint> points) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        if (points[i].value != null)
          FlSpot(i.toDouble(), meta.convert(points[i].value!)),
    ];
    final ys = [for (final s in spots) s.y];
    final minVal = ys.isEmpty ? 0.0 : ys.reduce((a, b) => a < b ? a : b);
    final maxVal = ys.isEmpty ? 10.0 : ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxVal - minVal) * 0.25).clamp(1.0, double.infinity);
    final minY = (minVal - pad).clamp(0.0, double.infinity);
    final maxY = maxVal + pad;
    final interval = _stepInterval(points.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: context.colors.separator, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  formatNumber(value, digits: meta.digits),
                  style: TextStyle(color: context.colors.inkSoft, fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i < 0 ||
                    i >= points.length ||
                    (i % interval.round()) != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortDate(points[i].date),
                    style: TextStyle(
                      color: context.colors.inkSoft,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.lineBarSpots == null ||
                response.lineBarSpots!.isEmpty) {
              return;
            }
            onTouchIndex(response.lineBarSpots!.first.x.round());
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colors.cardHigh,
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItems: (touchedSpots) => [
              for (final s in touchedSpots)
                LineTooltipItem(
                  '${_shortDate(points[s.x.round()].date)}\n'
                  '${formatNumber(s.y, digits: meta.digits)} ${meta.unit}',
                  TextStyle(
                    color: context.colors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: context.colors.adapt(meta.color),
            barWidth: 3,
            dotData: FlDotData(show: points.length <= 30),
            belowBarData: BarAreaData(
              show: true,
              color: context.colors.adapt(meta.color).withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendStatsRow extends StatelessWidget {
  const _TrendStatsRow({required this.meta, required this.points});

  final _MetricMeta meta;
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final p in points)
        if (p.value != null) meta.convert(p.value!),
    ];
    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);

    Widget tile(String label, double val) => Expanded(
      child: Semantics(
        label: '$label: ${formatNumber(val, digits: meta.digits)} ${meta.unit}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.colors.inkSoft, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatNumber(val, digits: meta.digits)} ${meta.unit}',
                  style: TextStyle(
                    color: context.colors.adapt(meta.color),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        tile('Trung bình', avg),
        const SizedBox(width: 10),
        tile('Cao nhất', max),
        const SizedBox(width: 10),
        tile('Thấp nhất', min),
      ],
    );
  }
}

class _TrendLoading extends StatelessWidget {
  const _TrendLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Đang tải biểu đồ xu hướng',
      child: Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: CircularProgressIndicator(color: context.colors.brand),
      ),
    );
  }
}

class _TrendError extends StatelessWidget {
  const _TrendError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi tải biểu đồ xu hướng: $message',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.colors.inkSoft,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Thử lại tải biểu đồ xu hướng',
              child: TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, color: context.colors.brand),
                label: Text(
                  'Thử lại',
                  style: TextStyle(color: context.colors.brand, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendEmpty extends StatelessWidget {
  const _TrendEmpty({
    required this.metricLabel,
    required this.rangeLabel,
    required this.icon,
  });

  final String metricLabel;
  final String rangeLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chưa có dữ liệu $metricLabel trong $rangeLabel qua',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.inkSoft, size: 48),
            const SizedBox(height: 12),
            Text(
              'Chưa có dữ liệu $metricLabel',
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Không có bản ghi nào trong $rangeLabel qua. Hãy ghi nhận bằng nút + ở thanh tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
