import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Thẻ chỉ số: tên có màu nhấn, số lớn, đường xu hướng nhỏ.
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
  });

  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final String caption;

  /// Các điểm của đường xu hướng, theo thứ tự thời gian.
  final List<double> trend;

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(caption, style: TextStyle(fontSize: 13, color: c.inkSoft)),
              const SizedBox(height: 14),
              SizedBox(
                height: 34,
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
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(at(points.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.points != points;
}
