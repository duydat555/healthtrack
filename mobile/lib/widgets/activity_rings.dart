import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Một vòng: màu và tiến độ (0 đến 1; trên 1 là vượt mục tiêu).
@immutable
class RingData {
  const RingData({required this.color, required this.progress});

  final Color color;
  final double progress;
}

/// Các vòng đồng tâm kiểu Activity Rings. Vòng đầu tiên ở ngoài cùng.
/// Vòng chạy từ 0 lên tiến độ khi hiện ra.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 140,
    this.strokeWidth = 18,
    this.gap = 3,
  });

  final List<RingData> rings;
  final double size;
  final double strokeWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Vòng tiến độ: ${rings.map((r) => '${(r.progress * 100).round()}%').join(', ')}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingsPainter(rings, strokeWidth, gap, t),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings, this.stroke, this.gap, this.t);

  final List<RingData> rings;
  final double stroke;
  final double gap;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final radius = size.width / 2 - stroke / 2 - i * (stroke + gap);
      if (radius <= 0) break;
      final rect = Rect.fromCircle(center: center, radius: radius);

      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ring.color.withValues(alpha: 0.24);
      canvas.drawCircle(center, radius, track);

      final progress = ring.progress * t;
      if (progress <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = ring.color;
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);

      // Vượt mục tiêu: đầu vòng đè lên đuôi, thêm bóng cho thấy chồng lớp
      if (progress > 1) {
        final end = -math.pi / 2 + 2 * math.pi * progress;
        final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
        canvas.drawCircle(
          tip,
          stroke / 2,
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
        canvas.drawCircle(tip, stroke / 2 - 1, Paint()..color = ring.color);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t ||
      old.stroke != stroke ||
      old.gap != gap ||
      old.rings != rings;
}
