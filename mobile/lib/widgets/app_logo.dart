import 'package:flutter/material.dart';

/// Logo HealthTrack: chữ H có thanh ngang là một nhịp tim. Hình học trên lưới 1024, phải khớp với
/// `scripts/render-app-icon.swift` (nguồn của icon ứng dụng và ảnh splash native).
///
/// [tile] vẽ cả ô icon bo góc với nền vàng; không thì chỉ vẽ nét chữ bằng [ink].
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 120,
    this.tile = true,
    this.dark = false,
    this.ink,
  });

  final double size;
  final bool tile;

  /// Bản tối của ô icon: nền đen, chữ vàng (giống icon ứng dụng ở chế độ tối).
  final bool dark;

  /// Màu nét khi không vẽ ô; mặc định lấy theo kiểu ô.
  final Color? ink;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'HealthTrack',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LogoPainter(tile: tile, dark: dark, ink: ink),
      ),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.tile, required this.dark, this.ink});

  final bool tile;
  final bool dark;
  final Color? ink;

  static const _stemW = 104.0;
  static const _top = 250.0;
  static const _bottom = 774.0;
  static const _leftX = 232.0;
  static const _rightX = 792.0;
  static const _beatWidth = 62.0;
  static const _beat = [
    Offset(_leftX + _stemW - 10, 512),
    Offset(408, 512),
    Offset(458, 384),
    Offset(514, 648),
    Offset(566, 512),
    Offset(_rightX - _stemW + 10, 512),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    final color =
        ink ?? (dark ? const Color(0xFFFFD60A) : const Color(0xFF1C1C1E));
    if (tile) {
      final rect = const Rect.fromLTWH(0, 0, 1024, 1024);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(229));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF3A3A3C), Color(0xFF141416)]
                : const [Color(0xFFFFD60A), Color(0xFFFFB800)],
          ).createShader(rect),
      );
    }
    final fill = Paint()..color = color;
    for (final x in [_leftX, _rightX - _stemW]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, _top, _stemW, _bottom - _top),
          const Radius.circular(_stemW / 2),
        ),
        fill,
      );
    }
    final path = Path()..moveTo(_beat.first.dx, _beat.first.dy);
    for (final p in _beat.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _beatWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.tile != tile || old.dark != dark || old.ink != ink;
}
