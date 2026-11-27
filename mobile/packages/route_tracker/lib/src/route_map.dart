import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Một điểm của đường đi để vẽ lên bản đồ. [speed] (m/s) quyết định màu; null là không rõ.
@immutable
class MapPoint {
  const MapPoint(this.lat, this.lon, [this.speed]);

  final double lat;
  final double lon;
  final double? speed;
}

/// Mảng phẳng [lat, lon, speed, ...] gửi sang native (tốc độ không rõ là −1).
Float64List flattenPoints(List<MapPoint> points) {
  final out = Float64List(points.length * 3);
  for (var i = 0; i < points.length; i++) {
    out[i * 3] = points[i].lat;
    out[i * 3 + 1] = points[i].lon;
    out[i * 3 + 2] = points[i].speed ?? -1;
  }
  return out;
}

/// Kiểu bản đồ.
enum RouteMapType { standard, satellite, hybrid }

/// Bảng màu chậm → nhanh mặc định: cam đậm, vàng, vàng nhạt (vàng là màu thương hiệu).
const defaultRouteGradient = [
  Color(0xFFFF5A1F),
  Color(0xFFFFB400),
  Color(0xFFFFE552),
];

/// Điều khiển một [RouteMapView]. Gọi trước khi bản đồ dựng xong thì lệnh bị bỏ qua; lộ trình
/// đã đặt bằng [setRoute] được gửi lại khi bản đồ sẵn sàng.
class RouteMapController {
  MethodChannel? _channel;
  List<MapPoint> _route = const [];

  /// true khi bản đồ đang bám theo người dùng; false khi người dùng đã kéo bản đồ đi chỗ khác
  /// (lúc đó nên hiện nút định vị lại).
  final ValueNotifier<bool> following = ValueNotifier(true);

  /// Gắn kênh của platform view; do [RouteMapView] gọi khi bản đồ native được tạo.
  @visibleForTesting
  void attach(MethodChannel channel) {
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onFollow') following.value = call.arguments as bool;
    });
    if (_route.isNotEmpty) setRoute(_route);
  }

  void _detach() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
  }

  Future<void> setRoute(List<MapPoint> points) async {
    _route = points;
    await _channel?.invokeMethod<void>('setRoute', {
      'points': flattenPoints(points),
    });
  }

  /// Thêm điểm vào cuối đường đi. Nên gom vài điểm một lần (mỗi 1–2 giây) vì native vẽ lại cả
  /// đường mỗi lần gọi.
  Future<void> appendPoints(List<MapPoint> points) async {
    _route = [..._route, ...points];
    await _channel?.invokeMethod<void>('appendPoints', {
      'points': flattenPoints(points),
    });
  }

  Future<void> setFollow(bool follow) =>
      _channel?.invokeMethod<void>('setFollow', {'follow': follow}) ??
      Future.value();

  /// Bám lại vị trí người dùng (nút định vị).
  Future<void> recenter() =>
      _channel?.invokeMethod<void>('recenter') ?? Future.value();

  /// Thu phóng cho vừa trọn đường đi (dùng ở trang tổng kết).
  Future<void> fitRoute({double padding = 48}) =>
      _channel?.invokeMethod<void>('fitRoute', {'padding': padding}) ??
      Future.value();

  Future<void> setMapType(RouteMapType type) =>
      _channel?.invokeMethod<void>('setMapType', {'mapType': type.name}) ??
      Future.value();

  void dispose() {
    _detach();
    following.dispose();
  }
}

/// Bản đồ Apple Maps native (iOS). Nơi khác vẽ bản dự phòng: đường đi trên nền tối, không có
/// bản đồ nền.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.controller,
    this.dark = true,
    this.mapType = RouteMapType.standard,
    this.followUser = true,
    this.gradient = defaultRouteGradient,
    @visibleForTesting this.forceFallback = false,
  });

  final RouteMapController controller;
  final bool dark;
  final RouteMapType mapType;

  /// Bám theo người dùng ngay khi mở (màn ghi); tắt ở trang tổng kết để xem cả đường đi.
  final bool followUser;
  final List<Color> gradient;
  final bool forceFallback;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const _viewType = 'healthtrack/route_map';

  bool get _native =>
      !widget.forceFallback && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(RouteMapView old) {
    super.didUpdateWidget(old);
    if (old.mapType != widget.mapType) {
      widget.controller.setMapType(widget.mapType);
    }
    if (old.dark != widget.dark) {
      widget.controller._channel?.invokeMethod<void>('setDark', {
        'dark': widget.dark,
      });
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_native) {
      return _FallbackMap(
        controller: widget.controller,
        dark: widget.dark,
        gradient: widget.gradient,
      );
    }
    return UiKitView(
      viewType: _viewType,
      creationParams: {
        'dark': widget.dark,
        'mapType': widget.mapType.name,
        'follow': widget.followUser,
        'gradient': [for (final c in widget.gradient) c.toARGB32()],
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) =>
          widget.controller.attach(MethodChannel('$_viewType/$id')),
    );
  }
}

/// Nơi không có Apple Maps: vẽ đường đi theo tốc độ trên nền tối, giữ giao diện không vỡ.
class _FallbackMap extends StatefulWidget {
  const _FallbackMap({
    required this.controller,
    required this.dark,
    required this.gradient,
  });

  final RouteMapController controller;
  final bool dark;
  final List<Color> gradient;

  @override
  State<_FallbackMap> createState() => _FallbackMapState();
}

class _FallbackMapState extends State<_FallbackMap> {
  /// Fallback không có kênh native: controller chỉ lưu lộ trình, nên đọc lại mỗi khung hình.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => CustomPaint(
      size: c.biggest,
      painter: RoutePainter(
        points: widget.controller._route,
        gradient: widget.gradient,
        background: widget.dark
            ? const Color(0xFF16161A)
            : const Color(0xFFEDEBE4),
        lineWidth: 6,
      ),
    ),
  );
}

/// Vẽ một đường đi vừa khít khung, màu theo tốc độ (phân vị 10–90%). Dùng cho bản đồ dự phòng,
/// bản đồ thu nhỏ và ảnh chia sẻ không cần bản đồ nền.
class RoutePainter extends CustomPainter {
  const RoutePainter({
    required this.points,
    this.gradient = defaultRouteGradient,
    this.background,
    this.lineWidth = 6,
    this.padding = 0.12,
  });

  final List<MapPoint> points;
  final List<Color> gradient;
  final Color? background;
  final double lineWidth;

  /// Lề tính theo tỉ lệ cạnh ngắn của khung.
  final double padding;

  /// Trung bình trượt ±[radius] điểm; tốc độ không rõ lấy theo điểm trước. Cùng cách làm với phía
  /// native để bản dự phòng và bản đồ thật cho cùng màu.
  static List<double> smoothSpeeds(List<MapPoint> pts, {int radius = 7}) {
    var last =
        pts
            .firstWhere(
              (p) => p.speed != null && p.speed! >= 0,
              orElse: () => const MapPoint(0, 0, 0),
            )
            .speed ??
        0;
    final filled = [
      for (final p in pts)
        last = (p.speed != null && p.speed! >= 0) ? p.speed! : last,
    ];
    final prefix = <double>[0];
    for (final v in filled) {
      prefix.add(prefix.last + v);
    }
    return [
      for (var i = 0; i < filled.length; i++)
        (prefix[math.min(filled.length - 1, i + radius) + 1] -
                prefix[math.max(0, i - radius)]) /
            (math.min(filled.length - 1, i + radius) -
                math.max(0, i - radius) +
                1),
    ];
  }

  /// Vị trí (0–1) của từng điểm theo tốc độ đã làm mượt và chuẩn hóa theo phân vị 10–90%; 0,5 khi
  /// tốc độ đều hoặc không rõ.
  static List<double> normalizedSpeeds(List<MapPoint> pts) {
    if (!pts.any((p) => p.speed != null && p.speed! >= 0)) {
      return List.filled(pts.length, 0.5);
    }
    final smooth = smoothSpeeds(pts);
    final sorted = [...smooth]..sort();
    if (sorted.length < 2) return List.filled(pts.length, 0.5);
    final lo = sorted[((sorted.length - 1) * 0.1).floor()];
    final hi = sorted[((sorted.length - 1) * 0.9).floor()];
    if (hi - lo <= 0.3) return List.filled(pts.length, 0.5);
    return [for (final v in smooth) ((v - lo) / (hi - lo)).clamp(0.0, 1.0)];
  }

  static Color colorAt(List<Color> stops, double t) {
    if (stops.length == 1) return stops.first;
    final scaled = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = math.min(scaled.floor(), stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    if (points.length < 2) return;
    // Phép chiếu equirectangular quanh vĩ độ giữa: đủ chính xác cho một buổi tập
    final midLat =
        (points.map((p) => p.lat).reduce(math.max) +
            points.map((p) => p.lat).reduce(math.min)) /
        2;
    final kx = math.cos(midLat * math.pi / 180);
    final xs = [for (final p in points) p.lon * kx];
    final ys = [for (final p in points) -p.lat];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    final pad = math.min(size.width, size.height) * padding;
    final scale = math.min(
      (size.width - pad * 2) / w,
      (size.height - pad * 2) / h,
    );
    final dx = (size.width - w * scale) / 2, dy = (size.height - h * scale) / 2;
    final pts = [
      for (var i = 0; i < points.length; i++)
        Offset(dx + (xs[i] - minX) * scale, dy + (ys[i] - minY) * scale),
    ];
    final t = normalizedSpeeds(points);

    final casing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = lineWidth * 1.7
      ..color = const Color(0x990F0F12);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, casing);
    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = lineWidth;
    for (var i = 1; i < pts.length; i++) {
      seg.color = colorAt(gradient, (t[i - 1] + t[i]) / 2);
      canvas.drawLine(pts[i - 1], pts[i], seg);
    }
    for (final (p, c) in [
      (pts.first, const Color(0xFF34C759)),
      (pts.last, const Color(0xFF111111)),
    ]) {
      canvas.drawCircle(p, lineWidth * 1.8, Paint()..color = Colors.white);
      canvas.drawCircle(p, lineWidth * 1.4, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.points != points ||
      old.gradient != gradient ||
      old.lineWidth != lineWidth ||
      old.background != background;
}
