import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:route_tracker/route_tracker.dart';

/// Nguồn vị trí cho màn ghi hoạt động. Tách khỏi [RouteTracker] để test thay bằng nguồn giả phát
/// lại buổi tập mẫu.
abstract class LocationSource {
  Future<bool> isAvailable();
  Future<LocationPermission> permission();
  Future<LocationPermission> requestPermission();
  Future<void> start();
  Future<void> stop();
  Stream<RawFix> fixes();
  Future<RawFix?> lastKnown();
  Future<void> setKeepAwake(bool on);
  Future<void> openSettings();
}

/// Nguồn thật: CoreLocation qua [RouteTracker].
class DeviceLocationSource implements LocationSource {
  const DeviceLocationSource([this._tracker = const RouteTracker()]);

  final RouteTracker _tracker;

  @override
  Future<bool> isAvailable() => _tracker.isAvailable();

  @override
  Future<LocationPermission> permission() => _tracker.permission();

  @override
  Future<LocationPermission> requestPermission() =>
      _tracker.requestPermission();

  @override
  Future<void> start() => _tracker.start(distanceFilterM: 3);

  @override
  Future<void> stop() => _tracker.stop();

  @override
  Stream<RawFix> fixes() => _tracker.fixes();

  @override
  Future<RawFix?> lastKnown() => _tracker.lastKnown();

  @override
  Future<void> setKeepAwake(bool on) => _tracker.setKeepAwake(on);

  @override
  Future<void> openSettings() => _tracker.openSettings();
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => const DeviceLocationSource(),
);
