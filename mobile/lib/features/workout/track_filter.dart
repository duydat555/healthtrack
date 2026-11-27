/// Lọc nhiễu GPS cho buổi tập: bỏ vị trí kém tin cậy, bỏ điểm nhảy vô lý, làm mượt bằng bộ lọc
/// Kalman một chiều. Dart thuần để test bằng dữ liệu mẫu, không cần thiết bị.
library;

import 'dart:math' as math;

import 'package:route_tracker/route_tracker.dart';

import 'workout.dart';
import 'workout_math.dart' as wm;

/// Thông số lọc theo môn.
class SportTuning {
  const SportTuning({
    required this.maxSpeed,
    required this.processNoise,
    required this.stillSpeed,
    required this.moveSpeed,
  });

  /// Tốc độ tối đa hợp lý (m/s); nhanh hơn nhiều lần là điểm nhảy.
  final double maxSpeed;

  /// Độ bất định thêm vào mỗi giây (m/s) cho bộ lọc Kalman: lớn thì bám sát GPS hơn.
  final double processNoise;

  /// Dưới tốc độ này (m/s) coi là đứng yên.
  final double stillSpeed;

  /// Từ tốc độ này (m/s) coi là đã di chuyển lại.
  final double moveSpeed;

  static SportTuning of(Sport sport) => switch (sport) {
    Sport.run => const SportTuning(
      maxSpeed: 12,
      processNoise: 3,
      stillSpeed: 0.7,
      moveSpeed: 1.2,
    ),
    Sport.walk => const SportTuning(
      maxSpeed: 4,
      processNoise: 1.5,
      stillSpeed: 0.4,
      moveSpeed: 0.8,
    ),
    Sport.ride => const SportTuning(
      maxSpeed: 25,
      processNoise: 6,
      stillSpeed: 1.0,
      moveSpeed: 2.0,
    ),
  };
}

class TrackFilter {
  TrackFilter(this.sport, {this.maxAccuracy = 20})
    : tuning = SportTuning.of(sport);

  final Sport sport;
  final SportTuning tuning;

  /// Bỏ vị trí có sai số ngang lớn hơn ngưỡng này (m).
  final double maxAccuracy;

  /// Số điểm nhảy liên tiếp tối đa bị bỏ; quá số này coi là GPS đã định vị lại thật và chấp nhận.
  static const _maxConsecutiveRejects = 3;

  double? _lat, _lon, _variance;
  RawFix? _lastAccepted;
  var _rejects = 0;

  /// Gọi khi bắt đầu đoạn mới (sau tạm dừng): bỏ trạng thái làm mượt, vì vị trí có thể đã khác.
  void startSegment() {
    _lat = _lon = _variance = null;
    _lastAccepted = null;
    _rejects = 0;
  }

  /// Trả điểm đã lọc, hoặc null nếu bỏ [f].
  TrackPoint? accept(RawFix f, {required int segment}) {
    if (f.accuracy < 0 || f.accuracy > maxAccuracy) return null;
    final last = _lastAccepted;
    if (last != null) {
      final dt = f.t.difference(last.t).inMilliseconds / 1000;
      if (dt <= 0) return null;
      final d = wm.haversine(last.lat, last.lon, f.lat, f.lon);
      // Cho dư 1,5 lần vì tốc độ tối đa chỉ là ước lượng, và cộng sai số hai điểm
      final limit = tuning.maxSpeed * 1.5 * dt + last.accuracy + f.accuracy;
      if (d > limit && _rejects < _maxConsecutiveRejects) {
        _rejects++;
        return null;
      }
    }
    _rejects = 0;

    final acc2 = math.max(f.accuracy, 1.0) * math.max(f.accuracy, 1.0);
    if (_lat == null || last == null) {
      _lat = f.lat;
      _lon = f.lon;
      _variance = acc2;
    } else {
      final dt = f.t.difference(last.t).inMilliseconds / 1000;
      var v = _variance! + dt * tuning.processNoise * tuning.processNoise;
      final k = v / (v + acc2);
      _lat = _lat! + k * (f.lat - _lat!);
      _lon = _lon! + k * (f.lon - _lon!);
      v = (1 - k) * v;
      _variance = v;
    }
    _lastAccepted = f;
    return TrackPoint(
      lat: _lat!,
      lon: _lon!,
      t: f.t,
      alt: f.alt,
      speed: f.speed,
      accuracy: math.sqrt(_variance!),
      segment: segment,
    );
  }
}
