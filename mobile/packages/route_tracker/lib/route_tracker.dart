import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Quyền vị trí của app.
enum LocationPermission {
  /// Chưa hỏi.
  notDetermined,

  /// Bị từ chối hoặc bị hạn chế.
  denied,

  /// Chỉ khi đang mở app: buổi tập sẽ ngừng ghi khi khóa máy.
  whenInUse,

  /// Luôn luôn: ghi tiếp được khi khóa máy.
  always,

  /// Nền tảng không hỗ trợ (Android hiện chưa có).
  unavailable;

  bool get granted => this == whenInUse || this == always;
}

/// Một vị trí GPS thô, chưa lọc.
@immutable
class RawFix {
  const RawFix({
    required this.lat,
    required this.lon,
    required this.t,
    required this.accuracy,
    this.alt,
    this.speed,
    this.course,
  });

  factory RawFix.fromMap(Map<Object?, Object?> m) => RawFix(
    lat: (m['lat']! as num).toDouble(),
    lon: (m['lon']! as num).toDouble(),
    t: DateTime.fromMillisecondsSinceEpoch(
      (m['t']! as num).toInt(),
      isUtc: true,
    ),
    accuracy: (m['acc']! as num).toDouble(),
    alt: (m['alt'] as num?)?.toDouble(),
    speed: (m['speed'] as num?)?.toDouble(),
    course: (m['course'] as num?)?.toDouble(),
  );

  final double lat;
  final double lon;
  final DateTime t;

  /// Sai số ngang (m). Số âm nghĩa là vị trí không hợp lệ.
  final double accuracy;
  final double? alt;

  /// Tốc độ tức thời (m/s) do hệ thống tính; null khi chưa có.
  final double? speed;

  /// Hướng di chuyển (độ, 0 là hướng bắc).
  final double? course;
}

/// Cầu nối tới CoreLocation. Trên nền tảng chưa hỗ trợ, `isAvailable` trả false và quyền là
/// [LocationPermission.unavailable].
class RouteTracker {
  const RouteTracker({MethodChannel? channel, EventChannel? fixes})
    : _channel = channel ?? const MethodChannel('healthtrack/route'),
      _fixes = fixes ?? const EventChannel('healthtrack/route/fixes');

  final MethodChannel _channel;
  final EventChannel _fixes;

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<LocationPermission> permission() => _permission('permission');

  /// Hiện hộp thoại xin quyền (nếu cần) và trả quyền sau khi người dùng trả lời. Đã có quyền
  /// "khi dùng app" thì xin nâng lên "luôn luôn".
  Future<LocationPermission> requestPermission() =>
      _permission('requestPermission');

  Future<LocationPermission> _permission(String method) async {
    try {
      final name = await _channel.invokeMethod<String>(method);
      return LocationPermission.values.firstWhere(
        (p) => p.name == name,
        orElse: () => LocationPermission.unavailable,
      );
    } on MissingPluginException {
      return LocationPermission.unavailable;
    }
  }

  /// Bắt đầu ghi. [distanceFilterM]: chỉ báo khi di chuyển thêm ít nhất chừng này mét (giảm pin).
  Future<void> start({double distanceFilterM = 3}) =>
      _channel.invokeMethod<void>('start', {
        'activity': 'fitness',
        'distanceFilter': distanceFilterM,
      });

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nền tảng không hỗ trợ: không có gì để dừng
    }
  }

  /// Vị trí gần nhất hệ thống biết (có thể cũ), để căn bản đồ trước khi bắt đầu ghi.
  Future<RawFix?> lastKnown() async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('lastKnown');
      return m == null ? null : RawFix.fromMap(m);
    } on MissingPluginException {
      return null;
    }
  }

  /// Luồng vị trí thô; chỉ có dữ liệu sau [start].
  Stream<RawFix> fixes() => _fixes.receiveBroadcastStream().map(
    (e) => RawFix.fromMap((e as Map).cast<Object?, Object?>()),
  );
}
