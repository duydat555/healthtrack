/// Phiên ghi một buổi tập: nhận vị trí thô, lọc, tính số liệu trực tiếp, tạm dừng (thủ công và tự
/// động khi đứng yên) và tạo [Workout] khi kết thúc. Dart thuần, không phụ thuộc đồng hồ hệ thống:
/// thời gian lấy từ chính các vị trí và từ [tick], nên test chạy được bằng dữ liệu mẫu.
library;

import 'package:route_tracker/route_tracker.dart';

import 'track_filter.dart';
import 'workout.dart';
import 'workout_math.dart' as wm;

enum SessionState { idle, running, paused }

/// Lý do đang tạm dừng.
enum PauseReason { manual, auto }

class TrackingSession {
  TrackingSession({
    required this.sport,
    required this.weightKg,
    this.autoPause = true,
    this.autoPauseAfter = const Duration(seconds: 10),
  }) : _filter = TrackFilter(sport),
       _tuning = SportTuning.of(sport);

  final Sport sport;
  final double weightKg;
  final bool autoPause;
  final Duration autoPauseAfter;
  final TrackFilter _filter;
  final SportTuning _tuning;

  final List<TrackPoint> _points = [];
  var _state = SessionState.idle;
  PauseReason? _pauseReason;
  var _segment = 0;
  var _distanceM = 0.0;
  var _movingSeconds = 0.0;
  DateTime? _lastFixAt;
  DateTime? _stillSince;
  TrackPoint? _pausedAt;

  SessionState get state => _state;
  PauseReason? get pauseReason => _pauseReason;
  List<TrackPoint> get points => List.unmodifiable(_points);

  /// Quãng đường đã ghi (m).
  double get distanceM => _distanceM;

  /// Thời gian vận động (giây), không tính lúc tạm dừng.
  double get movingSeconds => _movingSeconds;

  /// Nhịp trung bình toàn buổi (giây/km); null khi chưa đủ quãng đường.
  double? get avgPaceSecPerKm =>
      _distanceM < 20 ? null : _movingSeconds / _distanceM * 1000;

  /// Nhịp hiện tại (giây/km) tính trên [window] gần nhất; null khi chưa đủ dữ liệu hoặc đang đứng.
  double? currentPaceSecPerKm({Duration window = const Duration(seconds: 15)}) {
    if (_state != SessionState.running || _points.length < 2) return null;
    final end = _points.last;
    var d = 0.0, s = 0.0;
    for (var i = _points.length - 1; i > 0; i--) {
      final a = _points[i - 1], b = _points[i];
      if (a.segment != b.segment) break;
      d += wm.haversine(a.lat, a.lon, b.lat, b.lon);
      s += b.t.difference(a.t).inMilliseconds / 1000;
      if (end.t.difference(a.t) >= window) break;
    }
    return d < 5 || s <= 0 ? null : s / d * 1000;
  }

  void start() {
    if (_state != SessionState.idle) return;
    _state = SessionState.running;
    _filter.startSegment();
  }

  void pause() {
    if (_state != SessionState.running) return;
    _enterPause(PauseReason.manual);
  }

  void resume() {
    if (_state != SessionState.paused) return;
    _beginNewSegment();
  }

  void _enterPause(PauseReason reason) {
    _state = SessionState.paused;
    _pauseReason = reason;
    _pausedAt = _points.isEmpty ? null : _points.last;
    _stillSince = null;
  }

  void _beginNewSegment() {
    _segment++;
    _filter.startSegment();
    _state = SessionState.running;
    _pauseReason = null;
    _pausedAt = null;
    _stillSince = null;
    _lastFixAt = null;
  }

  /// Nhận một vị trí thô. Trả true nếu nó được thêm vào đường đi.
  bool onFix(RawFix f) {
    if (_state == SessionState.idle) return false;
    if (_state == SessionState.paused) {
      // Chỉ tạm dừng tự động mới tự tiếp tục; tạm dừng thủ công phải do người dùng bấm
      if (_pauseReason == PauseReason.auto && _movedAgain(f)) {
        _beginNewSegment();
      } else {
        return false;
      }
    }

    final p = _filter.accept(f, segment: _segment);
    if (p == null) return false;
    if (_points.isNotEmpty && _points.last.segment == p.segment) {
      final prev = _points.last;
      _distanceM += wm.haversine(prev.lat, prev.lon, p.lat, p.lon);
      _movingSeconds += p.t.difference(prev.t).inMilliseconds / 1000;
    }
    _points.add(p);
    _lastFixAt = f.t;

    if (autoPause) {
      final speed = f.speed;
      if (speed != null && speed >= 0 && speed < _tuning.stillSpeed) {
        _stillSince ??= f.t;
        if (f.t.difference(_stillSince!) >= autoPauseAfter) {
          _enterPause(PauseReason.auto);
        }
      } else {
        _stillSince = null;
      }
    }
    return true;
  }

  /// Gọi mỗi giây từ giao diện. Khi người dùng đứng yên, CoreLocation ngừng báo vị trí (vì
  /// `distanceFilter`), nên cần [tick] để phát hiện đứng yên theo thời gian.
  void tick(DateTime now) {
    if (!autoPause || _state != SessionState.running) return;
    final last = _lastFixAt;
    if (last != null && now.difference(last) >= autoPauseAfter) {
      _enterPause(PauseReason.auto);
    }
  }

  bool _movedAgain(RawFix f) {
    if (f.accuracy < 0 || f.accuracy > _filter.maxAccuracy) return false;
    final speed = f.speed;
    if (speed != null && speed >= _tuning.moveSpeed) return true;
    final at = _pausedAt;
    // Dịch chuyển rõ rệt khỏi chỗ dừng cũng tính là đã đi lại (khi hệ thống không báo tốc độ)
    return at != null &&
        wm.haversine(at.lat, at.lon, f.lat, f.lon) > 15 + f.accuracy;
  }

  /// Kết thúc và tạo buổi tập. Trả null nếu chưa ghi được điểm nào.
  Workout? finish({required String id, String? title}) {
    if (_points.isEmpty) return null;
    _state = SessionState.idle;
    final dist = wm.totalDistance(_points);
    final moving = wm.movingSeconds(_points);
    return Workout.fromPoints(
      id: id,
      sport: sport,
      points: _points,
      title: title,
      kcal: wm.workoutKcal(
        sport: sport,
        distanceM: dist,
        movingSeconds: moving,
        weightKg: weightKg,
      ),
    );
  }
}
