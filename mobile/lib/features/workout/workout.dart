/// Hợp đồng dữ liệu buổi tập ngoài trời (Phase 8). Dart thuần, không phụ thuộc Flutter, để dùng
/// chung cho app, công cụ sinh dữ liệu mẫu và test. Định dạng JSON mô tả ở
/// `docs/14-hop-dong-du-lieu-workout.md`; thay đổi ở đây phải cập nhật tài liệu đó.
library;

import 'workout_math.dart' as wm;

/// Môn tập. Tên JSON là `run`, `walk`, `ride`.
enum Sport {
  run('Chạy bộ'),
  walk('Đi bộ'),
  ride('Đạp xe');

  const Sport(this.label);

  final String label;

  static Sport fromJson(String name) =>
      Sport.values.firstWhere((s) => s.name == name, orElse: () => Sport.run);
}

/// Một điểm GPS đã lọc. [segment] tăng sau mỗi lần tạm dừng: quãng đường và thời gian vận động chỉ
/// tính trong cùng một đoạn, nên khoảng dừng không bị cộng vào.
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.t,
    this.alt,
    this.speed,
    this.accuracy,
    this.segment = 0,
  });

  final double lat;
  final double lon;
  final DateTime t;

  /// Độ cao so với mực nước biển (m).
  final double? alt;

  /// Tốc độ tức thời (m/s) do GPS báo.
  final double? speed;

  /// Sai số ngang (m).
  final double? accuracy;
  final int segment;

  Map<String, Object?> toJson() => {
    'lat': lat,
    'lon': lon,
    't': t.toUtc().toIso8601String(),
    if (alt != null) 'alt': alt,
    if (speed != null) 'speed': speed,
    if (accuracy != null) 'acc': accuracy,
    if (segment != 0) 'seg': segment,
  };

  factory TrackPoint.fromJson(Map<String, Object?> j) => TrackPoint(
    lat: (j['lat']! as num).toDouble(),
    lon: (j['lon']! as num).toDouble(),
    t: DateTime.parse(j['t']! as String),
    alt: (j['alt'] as num?)?.toDouble(),
    speed: (j['speed'] as num?)?.toDouble(),
    accuracy: (j['acc'] as num?)?.toDouble(),
    segment: (j['seg'] as num?)?.toInt() ?? 0,
  );
}

/// Một split: mỗi km tròn, km cuối có thể ngắn hơn.
class WorkoutSplit {
  const WorkoutSplit({
    required this.index,
    required this.distanceM,
    required this.seconds,
    required this.elevationDeltaM,
  });

  /// Km thứ mấy, bắt đầu từ 1.
  final int index;
  final double distanceM;

  /// Thời gian vận động của split (không tính lúc tạm dừng).
  final double seconds;
  final double elevationDeltaM;

  /// Nhịp (giây cho mỗi km) của split.
  double get paceSecPerKm => distanceM <= 0 ? 0 : seconds / distanceM * 1000;

  Map<String, Object?> toJson() => {
    'index': index,
    'distanceM': wm.round2(distanceM),
    'seconds': wm.round2(seconds),
    'paceSecPerKm': wm.round2(paceSecPerKm),
    'elevationDeltaM': wm.round2(elevationDeltaM),
  };

  factory WorkoutSplit.fromJson(Map<String, Object?> j) => WorkoutSplit(
    index: (j['index']! as num).toInt(),
    distanceM: (j['distanceM']! as num).toDouble(),
    seconds: (j['seconds']! as num).toDouble(),
    elevationDeltaM: (j['elevationDeltaM'] as num?)?.toDouble() ?? 0,
  );
}

/// Một buổi tập đã ghi xong.
class Workout {
  const Workout({
    required this.id,
    required this.sport,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.movingSeconds,
    required this.distanceM,
    required this.elevationGainM,
    required this.kcal,
    required this.splits,
    required this.points,
    required this.polyline,
  });

  /// Tạo buổi tập từ các điểm đã lọc: tự tính quãng đường, thời gian vận động, độ cao leo, split và
  /// polyline. [kcal] do nơi gọi tính (cần cân nặng của người dùng), xem [wm.workoutKcal].
  factory Workout.fromPoints({
    required String id,
    required Sport sport,
    required List<TrackPoint> points,
    required double kcal,
    String? title,
  }) {
    final start = points.isEmpty ? DateTime.now() : points.first.t;
    return Workout(
      id: id,
      sport: sport,
      title: title ?? defaultTitle(sport, start),
      startedAt: start,
      endedAt: points.isEmpty ? start : points.last.t,
      movingSeconds: wm.movingSeconds(points),
      distanceM: wm.totalDistance(points),
      elevationGainM: wm.elevationGain(points),
      kcal: kcal,
      splits: wm.computeSplits(points),
      points: points,
      polyline: wm.encodePolyline([for (final p in points) (p.lat, p.lon)]),
    );
  }

  /// Phiên bản định dạng JSON.
  static const schemaVersion = 1;

  final String id;
  final Sport sport;

  /// Tên buổi tập, ví dụ "Chạy buổi sáng".
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final double movingSeconds;
  final double distanceM;
  final double elevationGainM;
  final double kcal;
  final List<WorkoutSplit> splits;
  final List<TrackPoint> points;

  /// Đường đi mã hóa theo thuật toán Encoded Polyline của Google (độ chính xác 1e5). Đủ để vẽ bản
  /// đồ thu nhỏ và ảnh ghép mà không cần [points].
  final String polyline;

  /// Nhịp trung bình (giây cho mỗi km); null khi chưa có quãng đường.
  double? get avgPaceSecPerKm =>
      distanceM < 1 ? null : movingSeconds / distanceM * 1000;

  /// Tốc độ trung bình (km/h); null khi chưa có thời gian vận động.
  double? get avgSpeedKmh =>
      movingSeconds < 1 ? null : distanceM / movingSeconds * 3.6;

  Workout copyWith({String? title, double? kcal}) => Workout(
    id: id,
    sport: sport,
    title: title ?? this.title,
    startedAt: startedAt,
    endedAt: endedAt,
    movingSeconds: movingSeconds,
    distanceM: distanceM,
    elevationGainM: elevationGainM,
    kcal: kcal ?? this.kcal,
    splits: splits,
    points: points,
    polyline: polyline,
  );

  Map<String, Object?> toJson({bool withPoints = true}) => {
    'v': schemaVersion,
    'id': id,
    'sport': sport.name,
    'title': title,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'movingSeconds': wm.round2(movingSeconds),
    'distanceM': wm.round2(distanceM),
    'elevationGainM': wm.round2(elevationGainM),
    'avgPaceSecPerKm': avgPaceSecPerKm == null
        ? null
        : wm.round2(avgPaceSecPerKm!),
    'kcal': wm.round2(kcal),
    'splits': [for (final s in splits) s.toJson()],
    'polyline': polyline,
    if (withPoints) 'points': [for (final p in points) p.toJson()],
  };

  factory Workout.fromJson(Map<String, Object?> j) => Workout(
    id: j['id']! as String,
    sport: Sport.fromJson(j['sport']! as String),
    title: j['title'] as String? ?? '',
    startedAt: DateTime.parse(j['startedAt']! as String),
    endedAt: DateTime.parse(j['endedAt']! as String),
    movingSeconds: (j['movingSeconds']! as num).toDouble(),
    distanceM: (j['distanceM']! as num).toDouble(),
    elevationGainM: (j['elevationGainM'] as num?)?.toDouble() ?? 0,
    kcal: (j['kcal'] as num?)?.toDouble() ?? 0,
    splits: [
      for (final s in (j['splits'] as List?) ?? const [])
        WorkoutSplit.fromJson((s as Map).cast<String, Object?>()),
    ],
    points: [
      for (final p in (j['points'] as List?) ?? const [])
        TrackPoint.fromJson((p as Map).cast<String, Object?>()),
    ],
    polyline: j['polyline'] as String? ?? '',
  );
}

/// Tên mặc định theo môn và buổi trong ngày, ví dụ "Chạy bộ buổi sáng".
String defaultTitle(Sport sport, DateTime start) {
  final h = start.toLocal().hour;
  final part = h < 11
      ? 'buổi sáng'
      : h < 14
      ? 'buổi trưa'
      : h < 18
      ? 'buổi chiều'
      : 'buổi tối';
  return '${sport.label} $part';
}
