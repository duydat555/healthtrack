import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Một vòng: màu và tiến độ (0 đến 1; trên 1 là vượt mục tiêu).
@immutable
class RingData {
  const RingData({required this.color, required this.progress});

  final Color color;
  final double progress;
}

/// Các vòng đồng tâm kiểu Activity Rings. Vòng đầu tiên ở ngoài cùng.
/// Mỗi vòng có gradient quét theo cung và vầng sáng nhẹ ở Dark Mode.
/// Vòng chạy từ 0 lên tiến độ khi hiện ra (bỏ qua nếu bật Giảm chuyển động).
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 140,
    this.strokeWidth = 18,
    this.gap = 4,
    this.center,
  });

  final List<RingData> rings;
  final double size;
  final double strokeWidth;
  final double gap;

  /// Nội dung đặt giữa các vòng (ví dụ phần trăm tổng).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final glow = context.isDark;
    return Semantics(
      label:
          'Vòng tiến độ: ${rings.map((r) => '${(r.progress * 100).round()}%').join(', ')}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.of(context, const Duration(milliseconds: 1200)),
        curve: AppMotion.curve,
        builder: (context, t, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingsPainter(rings, strokeWidth, gap, t, glow),
            child: center == null ? null : Center(child: center),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings, this.stroke, this.gap, this.t, this.glow);

  final List<RingData> rings;
  final double stroke;
  final double gap;
  final double t;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final radius = size.width / 2 - stroke / 2 - i * (stroke + gap);
      if (radius <= 0) break;
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ring.color.withValues(alpha: 0.16),
      );

      final progress = ring.progress * t;
      if (progress <= 0) continue;
      final fraction = progress.clamp(0.0, 1.0);
      final sweep = 2 * math.pi * fraction;

      // Gradient quét: đuôi tối hơn, đầu sáng hơn, nên nhìn ra chiều chạy của vòng.
      final light = Color.lerp(ring.color, Colors.white, 0.3)!;
      final dark = Color.lerp(ring.color, Colors.black, 0.18)!;
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [dark, ring.color, light],
        stops: [
          0,
          (fraction * 0.6).clamp(0.01, 0.99),
          fraction.clamp(0.02, 1.0),
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = shader;

      if (glow) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = stroke
            ..color = ring.color.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);

      // Vượt mục tiêu: đầu vòng đè lên đuôi, thêm bóng cho thấy chồng lớp
      if (progress > 1) {
        final end = -math.pi / 2 + 2 * math.pi * progress;
        final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
        canvas.drawCircle(
          tip,
          stroke / 2,
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
        canvas.drawCircle(tip, stroke / 2 - 1, Paint()..color = light);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t ||
      old.stroke != stroke ||
      old.gap != gap ||
      old.glow != glow ||
      old.rings != rings;
}
