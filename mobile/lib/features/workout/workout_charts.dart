import 'workout.dart';
import 'workout_math.dart' as wm;

/// Một điểm của biểu đồ: [km] kể từ lúc bắt đầu, [value] theo trục tung.
class ChartPoint {
  const ChartPoint(this.km, this.value);

  final double km;
  final double value;
}

/// Quãng đường và thời gian vận động cộng dồn tại từng điểm; bỏ qua quãng giữa hai đoạn.
({List<double> dist, List<double> moving}) _cumulative(List<TrackPoint> pts) {
  final dist = <double>[0], moving = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    if (a.segment != b.segment) {
      dist.add(dist.last);
      moving.add(moving.last);
      continue;
    }
    dist.add(dist.last + wm.haversine(a.lat, a.lon, b.lat, b.lon));
    moving.add(moving.last + b.t.difference(a.t).inMilliseconds / 1000);
  }
  return (dist: dist, moving: moving);
}

/// Nội suy giá trị [ys] tại quãng đường [d] trên dãy [xs] không giảm.
double _at(List<double> xs, List<double> ys, double d) {
  var lo = 0, hi = xs.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (xs[mid] < d) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return ys[0];
  final x0 = xs[lo - 1], x1 = xs[lo];
  if (x1 - x0 < 1e-9) return ys[lo];
  return ys[lo - 1] + (ys[lo] - ys[lo - 1]) * (d - x0) / (x1 - x0);
}

/// Độ cao theo quãng đường, làm mượt nhẹ để bỏ nhiễu GPS. Rỗng khi thiếu dữ liệu độ cao.
List<ChartPoint> elevationProfile(List<TrackPoint> pts, {int buckets = 80}) {
  if (pts.length < 2 || pts.every((p) => p.alt == null)) return const [];
  var last = pts.firstWhere((p) => p.alt != null).alt!;
  final alt = [for (final p in pts) last = p.alt ?? last];
  final c = _cumulative(pts);
  final total = c.dist.last;
  if (total < 10) return const [];
  final raw = [
    for (var i = 0; i <= buckets; i++) _at(c.dist, alt, total * i / buckets),
  ];
  return [
    for (var i = 0; i <= buckets; i++)
      ChartPoint(total * i / buckets / 1000, _mean(raw, i - 1, i + 1)),
  ];
}

/// Nhịp (giây/km) theo quãng đường, tính trên từng đoạn đều nhau rồi làm mượt. Rỗng khi quá ngắn.
List<ChartPoint> paceProfile(List<TrackPoint> pts, {int buckets = 60}) {
  if (pts.length < 2) return const [];
  final c = _cumulative(pts);
  final total = c.dist.last;
  if (total < 100) return const [];
  final step = total / buckets;
  final raw = <double>[];
  for (var i = 0; i < buckets; i++) {
    final dt =
        _at(c.dist, c.moving, step * (i + 1)) - _at(c.dist, c.moving, step * i);
    // Giới hạn 3:00 đến 20:00/km để một đoạn đứng yên không làm vỡ thang biểu đồ
    raw.add((dt / step * 1000).clamp(180, 1200));
  }
  return [
    for (var i = 0; i < buckets; i++)
      ChartPoint((i + 0.5) * step / 1000, _mean(raw, i - 1, i + 1)),
  ];
}

double _mean(List<double> v, int from, int to) {
  final a = from.clamp(0, v.length - 1), b = to.clamp(0, v.length - 1);
  var s = 0.0;
  for (var i = a; i <= b; i++) {
    s += v[i];
  }
  return s / (b - a + 1);
}
