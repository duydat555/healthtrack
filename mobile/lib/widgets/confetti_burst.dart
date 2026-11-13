import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Pháo giấy một lần khi đạt huy hiệu mới. Không nhận chạm, tự biến mất, và không hiện nếu
/// người dùng bật Giảm chuyển động.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.colors = const []});

  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    final palette = widget.colors.isEmpty
        ? const [
            AppColors.steps,
            AppColors.water,
            AppColors.sleep,
            AppColors.weight,
            AppColors.meal,
          ]
        : widget.colors;
    _pieces = List.generate(
      44,
      (_) => _Piece(
        angle: -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.1,
        speed: 140 + rnd.nextDouble() * 220,
        spin: (rnd.nextDouble() - 0.5) * 12,
        size: 5 + rnd.nextDouble() * 5,
        color: palette[rnd.nextInt(palette.length)],
      ),
    );
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (!_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.55);
    for (final p in pieces) {
      final time = t * 1.8;
      final dx = math.cos(p.angle) * p.speed * time;
      // Bay lên rồi rơi xuống theo trọng lực
      final dy = math.sin(p.angle) * p.speed * time + 260 * time * time;
      final alpha = (1 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
      canvas
        ..save()
        ..translate(origin.dx + dx, origin.dy + dy)
        ..rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = p.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
