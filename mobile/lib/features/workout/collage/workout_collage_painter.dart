import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../workout.dart';
import '../workout_math.dart' as wm;

enum CollageTemplate {
  glass('Thanh mờ', 0.58, 0.58, Offset(0.5, 0.43)),
  centered('Đường đi lớn', 0.82, 0.56, Offset(0.5, 0.49)),
  sticker('Nhãn dán', 0.55, 0.30, Offset(0.5, 0.44));

  const CollageTemplate(
    this.label,
    this.routeWidth,
    this.routeHeight,
    this.routeCenter,
  );

  final String label;
  final double routeWidth;
  final double routeHeight;
  final Offset routeCenter;
}

enum CollageFormat {
  story('Story 9:16', 1920),
  post('Post 4:5', 1350);

  const CollageFormat(this.label, this.height);

  static const width = 1080;
  final String label;
  final int height;

  Size get size => Size(width.toDouble(), height.toDouble());
  double get aspectRatio => width / height;
}

typedef CollagePlacement = ({Offset center, double scale});

const minRouteScale = 0.4;
const maxRouteScale = 2.5;

/// Tâm và tiêu điểm cử chỉ đều tính theo tỉ lệ của khung ảnh.
CollagePlacement transformCollageRoute({
  required CollagePlacement initial,
  required Offset initialFocalPoint,
  required Offset focalPoint,
  required double pinchScale,
}) {
  final scale = (initial.scale * pinchScale).clamp(
    minRouteScale,
    maxRouteScale,
  );
  final center =
      focalPoint +
      (initial.center - initialFocalPoint) * (scale / initial.scale);
  return (
    center: Offset(center.dx.clamp(0.08, 0.92), center.dy.clamp(0.08, 0.92)),
    scale: scale,
  );
}

/// Ưu tiên GPS chi tiết để giữ các đoạn tách nhau khi buổi tập đã tạm dừng.
/// Bản ghi rút gọn có thể chỉ có Google Encoded Polyline.
Path? collageRoutePath(Workout workout) {
  final List<(double, double, int)> coordinates;
  if (workout.points.length >= 2) {
    coordinates = [for (final p in workout.points) (p.lat, p.lon, p.segment)];
  } else {
    try {
      coordinates = [
        for (final (lat, lon) in wm.decodePolyline(workout.polyline))
          (lat, lon, 0),
      ];
    } on RangeError {
      return null;
    }
  }
  if (coordinates.length < 2) return null;
  final (originLat, originLon, _) = coordinates.first;
  final longitudeScale = math.cos(originLat * math.pi / 180);
  final path = Path();
  int? lastSegment;
  var hasLine = false;
  for (final (lat, lon, segment) in coordinates) {
    final x = (lon - originLon) * longitudeScale;
    final y = originLat - lat;
    if (lastSegment == segment) {
      path.lineTo(x, y);
      hasLine = true;
    } else {
      path.moveTo(x, y);
      lastSegment = segment;
    }
  }
  final bounds = path.getBounds();
  final extent = math.max(bounds.width, bounds.height);
  if (!hasLine || extent == 0) return null;
  final centered = path.shift(-bounds.center);
  return centered.transform(
    Matrix4.diagonal3Values(1 / extent, 1 / extent, 1).storage,
  );
}

/// Một bộ vẽ dùng chung cho khung tương tác và PNG, độc lập với mật độ màn hình.
class WorkoutCollagePainter extends CustomPainter {
  const WorkoutCollagePainter({
    required this.workout,
    required this.route,
    required this.template,
    required this.placement,
    required this.textColor,
    required this.backgroundColor,
    required this.backgroundOpacity,
    this.photo,
  });

  final Workout workout;
  final Path? route;
  final CollageTemplate template;
  final CollagePlacement placement;
  final Color textColor;
  final Color backgroundColor;
  final double backgroundOpacity;
  final ui.Image? photo;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const width = 360.0;
    final height = size.height / size.width * width;
    final frame = Rect.fromLTWH(0, 0, width, height);
    canvas.save();
    canvas.scale(size.width / width);
    canvas.clipRect(frame);
    if (template != CollageTemplate.sticker) {
      _drawBackground(canvas, frame);
    }
    _drawRoute(canvas, frame);
    switch (template) {
      case CollageTemplate.glass:
        final bar = RRect.fromRectAndRadius(
          Rect.fromLTWH(16, height - 114, width - 32, 96),
          const Radius.circular(AppRadius.card),
        );
        _drawGlassBar(canvas, frame, bar);
        _drawSport(canvas, bar.top + 12);
        _drawStats(canvas, frame.center.dx, 304, bar.top + 35);
      case CollageTemplate.centered:
        _drawSport(canvas, height * 0.13);
        _drawStats(canvas, frame.center.dx, 322, height * 0.79);
      case CollageTemplate.sticker:
        _drawSport(canvas, height * 0.24);
        _drawStats(canvas, frame.center.dx, 282, height * 0.63);
    }
    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Rect frame) {
    canvas.drawRect(frame, Paint()..color = AppColors.background);
    if (photo case final image?) {
      _drawPhoto(canvas, frame, image);
    }
    canvas.drawRect(
      frame,
      Paint()..color = backgroundColor.withValues(alpha: backgroundOpacity),
    );
  }

  void _drawPhoto(Canvas canvas, Rect frame, ui.Image image) {
    final source = Size(image.width.toDouble(), image.height.toDouble());
    final crop = applyBoxFit(BoxFit.cover, source, frame.size).source;
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(crop, Offset.zero & source),
      frame,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _drawGlassBar(Canvas canvas, Rect frame, RRect bar) {
    canvas.save();
    canvas.clipRRect(bar);
    if (photo != null) {
      canvas.saveLayer(
        bar.outerRect.inflate(20),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
      );
      _drawBackground(canvas, frame);
      canvas.restore();
    }
    canvas.drawRRect(
      bar,
      Paint()..color = AppColors.onBrand.withValues(alpha: 0.54),
    );
    canvas.restore();
    canvas.drawRRect(
      bar.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.ink.withValues(alpha: 0.28),
    );
  }

  void _drawRoute(Canvas canvas, Rect frame) {
    final path = route;
    if (path == null) return;
    final defaultExtent = math.min(
      frame.width * template.routeWidth,
      frame.height *
          template.routeHeight /
          math.max(path.getBounds().height, 0.01),
    );
    final extent = defaultExtent * placement.scale;
    canvas.save();
    canvas.translate(
      frame.width * placement.center.dx,
      frame.height * placement.center.dy,
    );
    canvas.scale(extent);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      path,
      stroke
        ..color = AppColors.onBrand
        ..strokeWidth = 8 / extent,
    );
    canvas.drawPath(
      path,
      stroke
        ..color = AppColors.brand
        ..strokeWidth = 4.5 / extent,
    );
    canvas.restore();
  }

  void _drawSport(Canvas canvas, double top) {
    _drawText(
      canvas,
      workout.sport.label,
      180,
      top,
      320,
      const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
  }

  void _drawStats(Canvas canvas, double center, double width, double top) {
    final ride = workout.sport == Sport.ride;
    final speed = workout.avgSpeedKmh;
    final stats = [
      (
        'Quãng đường',
        '${formatNumber(workout.distanceM / 1000, digits: 2)} km',
      ),
      ('Thời gian', wm.formatDuration(workout.movingSeconds)),
      if (ride)
        ('Tốc độ TB', speed == null ? '—' : '${formatNumber(speed)} km/h')
      else
        ('Nhịp TB', '${wm.formatPace(workout.avgPaceSecPerKm)}/km'),
    ];
    final columnWidth = width / stats.length;
    for (final (index, (label, value)) in stats.indexed) {
      final x = center - width / 2 + columnWidth * (index + 0.5);
      _drawText(canvas, value, x, top, columnWidth, AppFonts.number(19));
      _drawText(
        canvas,
        label,
        x,
        top + 25,
        columnWidth,
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double width,
    TextStyle style,
  ) {
    final outline = textColor.computeLuminance() > 0.32
        ? AppColors.onBrand
        : AppColors.ink;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    );
    for (final paint in [
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.5,
      Paint()..color = textColor,
    ]) {
      painter.text = TextSpan(
        text: text,
        style: style.copyWith(color: null, foreground: paint),
      );
      painter.layout(maxWidth: width - 4);
      painter.paint(canvas, Offset(x - painter.width / 2, y));
    }
    painter.dispose();
  }

  Future<Uint8List> renderPng(CollageFormat format) async {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), format.size);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(CollageFormat.width, format.height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Không mã hóa được PNG');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  @override
  bool shouldRepaint(WorkoutCollagePainter old) =>
      old.workout != workout ||
      old.route != route ||
      old.template != template ||
      old.placement != placement ||
      old.textColor != textColor ||
      old.backgroundColor != backgroundColor ||
      old.backgroundOpacity != backgroundOpacity ||
      old.photo != photo;
}
