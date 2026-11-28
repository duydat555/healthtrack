import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:route_tracker/route_tracker.dart';

import '../../core/app_icons.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/core_widgets.dart';
import '../../widgets/form_sheet.dart';
import 'workout.dart';
import 'workout_charts.dart';
import 'workout_math.dart' as wm;
import 'workout_repository.dart';

/// Trang tổng kết một buổi tập: bản đồ, số liệu, split, biểu đồ nhịp và độ cao.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutProvider(id));
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Tổng kết buổi tập')),
        leading: RoundIconButton(
          tooltip: 'Quay lại',
          semanticLabel: 'Quay lại',
          symbol: 'chevron.left',
          icon: AppIcons.back,
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          if (async.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: RoundIconButton(
                tooltip: 'Xóa buổi tập',
                semanticLabel: 'Xóa buổi tập',
                symbol: 'trash',
                icon: AppIcons.trash,
                onTap: () => _confirmDelete(context, ref, async.value!),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Không đọc được buổi tập này.',
          onRetry: () => ref.invalidate(workoutProvider(id)),
        ),
        data: (w) => w == null
            ? const EmptyState(message: 'Không tìm thấy buổi tập này.')
            : SummaryBody(workout: w),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Workout w,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog.adaptive(
        title: const Text('Xóa buổi tập?'),
        content: const Text(
          'Buổi tập này sẽ bị xóa khỏi máy, không khôi phục được.',
        ),
        actions: [
          adaptiveDialogAction(
            d,
            label: 'Hủy',
            onPressed: () => Navigator.pop(d, false),
          ),
          adaptiveDialogAction(
            d,
            label: 'Xóa',
            destructive: true,
            onPressed: () => Navigator.pop(d, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workoutRepositoryProvider).delete(w.id);
    ref.invalidate(workoutsProvider);
    if (context.mounted) context.pop();
  }
}

/// Nội dung trang tổng kết. Tách riêng để test dựng được với một [Workout] có sẵn.
class SummaryBody extends StatefulWidget {
  const SummaryBody({super.key, required this.workout, this.snapshot});

  final Workout workout;

  /// Thay cho việc chụp bản đồ thật (test); trả null là không có ảnh.
  final Future<Uint8List?> Function(Workout, bool dark)? snapshot;

  @override
  State<SummaryBody> createState() => _SummaryBodyState();
}

class _SummaryBodyState extends State<SummaryBody> {
  Future<Uint8List?>? _image;
  bool? _dark;

  Workout get w => widget.workout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = context.colors.isDark;
    if (_dark != dark) {
      _dark = dark;
      _image = (widget.snapshot ?? _capture)(w, dark);
    }
  }

  static Future<Uint8List?> _capture(Workout w, bool dark) async {
    try {
      return await RouteTracker().snapshotRoute(
        [for (final p in w.points) MapPoint(p.lat, p.lon, p.speed)],
        dark: dark,
        width: 1080,
        height: 810,
      );
    } on Object {
      return null; // không có mạng hoặc nền tảng chưa hỗ trợ: vẽ bản dự phòng
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ride = w.sport == Sport.ride;
    final paceValue = ride
        ? formatNumber(w.avgSpeedKmh ?? 0)
        : wm.formatPace(w.avgPaceSecPerKm);
    final local = w.startedAt.toLocal();
    final pace = paceProfile(w.points);
    final elevation = elevationProfile(w.points);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            w.title,
            style: TextStyle(
              color: c.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${w.sport.label} · ${formatHeaderDate(local)}, ${formatTime(local)}',
          style: context.text.caption,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Semantics(
              image: true,
              label:
                  'Bản đồ đường đi dài ${formatNumber(w.distanceM / 1000, digits: 2)} ki-lô-mét',
              child: FutureBuilder<Uint8List?>(
                future: _image,
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes != null) {
                    return Image.memory(bytes, fit: BoxFit.cover);
                  }
                  return _FallbackRoute(
                    workout: w,
                    loading:
                        !snap.hasData &&
                        snap.connectionState != ConnectionState.done,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label:
              'Quãng đường ${formatNumber(w.distanceM / 1000, digits: 2)} ki-lô-mét',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatNumber(w.distanceM / 1000, digits: 2),
                  style: AppFonts.number(
                    56,
                    color: c.ink,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('km', style: context.text.body),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Thời gian',
                value: wm.formatDuration(w.movingSeconds),
              ),
            ),
            Expanded(
              child: _Stat(
                label: ride ? 'Tốc độ TB (km/h)' : 'Nhịp TB (/km)',
                value: paceValue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Độ cao leo',
                value: '${w.elevationGainM.round()} m',
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'Năng lượng',
                value: '${w.kcal.round()} kcal',
              ),
            ),
          ],
        ),
        if (w.splits.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Section('Từng km'),
          _Splits(splits: w.splits, ride: ride),
        ],
        if (pace.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Section(ride ? 'Tốc độ' : 'Nhịp'),
          _ChartCard(
            points: [
              for (final p in pace)
                ChartPoint(p.km, ride ? 3600 / p.value : p.value),
            ],
            invert: !ride, // nhịp nhanh (số nhỏ) hiện cao hơn
            format: ride
                ? (v) => '${formatNumber(v)} km/h'
                : (v) => '${wm.formatPace(v)}/km',
            color: c.brandText,
            summary: ride ? 'Tốc độ theo quãng đường' : 'Nhịp theo quãng đường',
          ),
        ],
        if (elevation.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Section('Độ cao'),
          _ChartCard(
            points: elevation,
            invert: false,
            format: (v) => '${v.round()} m',
            color: c.steps,
            summary: 'Độ cao theo quãng đường',
          ),
        ],
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Chia sẻ',
          onPressed: () =>
              context.push('/workout/${Uri.encodeComponent(w.id)}/collage'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppFonts.number(28, color: context.colors.ink)),
          const SizedBox(height: 6),
          Text(label, style: context.text.caption),
        ],
      ),
    ),
  );
}

/// Đường đi vẽ bằng [RoutePainter] khi chưa có ảnh bản đồ (đang tải, không có mạng, hoặc không
/// phải iPhone).
class _FallbackRoute extends StatelessWidget {
  const _FallbackRoute({required this.workout, required this.loading});

  final Workout workout;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.isDark;
    return CustomPaint(
      painter: RoutePainter(
        points: [
          for (final p in workout.points) MapPoint(p.lat, p.lon, p.speed),
        ],
        background: dark ? const Color(0xFF16161A) : const Color(0xFFEDEBE4),
        lineWidth: 5,
      ),
      child: loading
          ? const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : null,
    );
  }
}

class _Splits extends StatelessWidget {
  const _Splits({required this.splits, required this.ride});

  final List<WorkoutSplit> splits;
  final bool ride;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paces = [for (final s in splits) s.paceSecPerKm];
    final fastest = paces.reduce((a, b) => a < b ? a : b);
    final slowest = paces.reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (final s in splits)
            Builder(
              builder: (_) {
                final partial = s.distanceM < 990;
                // Thanh dài hơn = nhanh hơn; nhịp càng nhỏ càng nhanh
                final frac = slowest - fastest < 1
                    ? 1.0
                    : 0.35 +
                          0.65 *
                              (slowest - s.paceSecPerKm) /
                              (slowest - fastest);
                final label = ride
                    ? '${formatNumber(3600 / s.paceSecPerKm)} km/h'
                    : wm.formatPace(s.paceSecPerKm);
                final km = partial
                    ? '${formatNumber(s.distanceM / 1000, digits: 2)} km'
                    : '${s.index}';
                return Semantics(
                  label:
                      'Km $km, ${ride ? 'tốc độ' : 'nhịp'} $label${s.paceSecPerKm == fastest ? ', nhanh nhất' : ''}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(km, style: context.text.caption),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: frac,
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.paceSecPerKm == fastest
                                        ? c.brandText
                                        : c.brandText.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 74,
                            child: Text(
                              label,
                              textAlign: TextAlign.right,
                              style: AppFonts.number(
                                16,
                                color: c.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.points,
    required this.invert,
    required this.format,
    required this.color,
    required this.summary,
  });

  final List<ChartPoint> points;
  final bool invert;
  final String Function(double) format;
  final Color color;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final values = [for (final p in points) p.value];
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Semantics(
        label: '$summary: thấp nhất ${format(lo)}, cao nhất ${format(hi)}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(format(invert ? hi : lo), style: context.text.caption),
                  Text(format(invert ? lo : hi), style: context.text.caption),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LinePainter(
                    points: points,
                    invert: invert,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0 km', style: context.text.caption),
                  Text(
                    '${formatNumber(points.last.km, digits: 2)} km',
                    style: context.text.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.points,
    required this.invert,
    required this.color,
  });

  final List<ChartPoint> points;
  final bool invert;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = [for (final p in points) p.km];
    final ys = [for (final p in points) p.value];
    final x0 = xs.first, x1 = xs.last;
    var lo = ys.reduce((a, b) => a < b ? a : b);
    var hi = ys.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    Offset at(int i) {
      final fx = x1 == x0 ? 0.0 : (xs[i] - x0) / (x1 - x0);
      var fy = (ys[i] - lo) / (hi - lo); // 0 = thấp nhất
      if (invert) fy = 1 - fy;
      return Offset(fx * size.width, size.height * (1 - fy));
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.color != color || old.invert != invert;
}
