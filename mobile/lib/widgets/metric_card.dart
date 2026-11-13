import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Thẻ chỉ số kiểu Apple Health: icon và tên theo màu danh mục, giờ cập nhật bên phải, số lớn kèm
/// đơn vị nhỏ hơn, đường xu hướng mảnh.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.caption,
    required this.trend,
    this.timeLabel,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final String caption;

  /// Các điểm của đường xu hướng, theo thứ tự thời gian.
  final List<double> trend;

  /// Mốc cập nhật nhỏ ở góc phải tiêu đề (ví dụ "09:41"); null thì ẩn.
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$title: $value $unit. $caption',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.cardTitle.copyWith(color: color),
                    ),
                  ),
                  if (timeLabel != null)
                    Text(timeLabel!, style: context.text.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppFonts.number(30, color: c.ink),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: context.text.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(caption, style: context.text.caption),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 32,
                width: double.infinity,
                child: CustomPaint(painter: _SparkPainter(trend, color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final lo = points.reduce((a, b) => a < b ? a : b);
    final hi = points.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(
      size.width * i / (points.length - 1),
      size.height - 4 - (size.height - 8) * ((points[i] - lo) / span),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final prev = at(i - 1);
      final cur = at(i);
      final mid = (prev.dx + cur.dx) / 2;
      path.cubicTo(mid, prev.dy, mid, cur.dy, cur.dx, cur.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(at(points.length - 1), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.points != points;
}
