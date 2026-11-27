/// Phép tính trên đường đi GPS, dùng chung cho tracking, trang tổng kết, ảnh ghép và dữ liệu mẫu.
/// Dart thuần để test được mà không cần thiết bị.
library;

import 'dart:math' as math;

import 'workout.dart';

double round2(double v) => (v * 100).roundToDouble() / 100;

const _earthRadiusM = 6371008.8;

/// Khoảng cách theo đường tròn lớn (công thức haversine), tính bằng mét.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
}

/// Tổng quãng đường (m), chỉ cộng giữa hai điểm cùng đoạn (không cộng qua lúc tạm dừng).
double totalDistance(List<TrackPoint> pts) {
  var d = 0.0;
  for (var i = 1; i < pts.length; i++) {
    if (pts[i].segment != pts[i - 1].segment) continue;
    d += haversine(pts[i - 1].lat, pts[i - 1].lon, pts[i].lat, pts[i].lon);
  }
  return d;
}

/// Thời gian vận động (giây): tổng thời lượng từng đoạn.
double movingSeconds(List<TrackPoint> pts) {
  var s = 0.0;
  for (var i = 1; i < pts.length; i++) {
    if (pts[i].segment != pts[i - 1].segment) continue;
    s += pts[i].t.difference(pts[i - 1].t).inMilliseconds / 1000;
  }
  return s;
}

/// Độ cao leo (m). Độ cao GPS dao động vài mét, nên chỉ cộng khi tăng vượt ngưỡng [threshold] so
/// với mốc thấp gần nhất (trễ có ngưỡng), tránh cộng dồn nhiễu.
double elevationGain(List<TrackPoint> pts, {double threshold = 3}) {
  double? base;
  var gain = 0.0;
  for (final p in pts) {
    final a = p.alt;
    if (a == null) continue;
    if (base == null) {
      base = a;
    } else if (a - base >= threshold) {
      gain += a - base;
      base = a;
    } else if (a < base) {
      base = a;
    }
  }
  return gain;
}

/// Chia split mỗi [unitM] mét (mặc định 1 km). Mốc km rơi giữa hai điểm thì nội suy thời gian và
/// độ cao theo tỉ lệ quãng đường. Split cuối là phần lẻ còn lại (nếu từ 10 m trở lên).
List<WorkoutSplit> computeSplits(List<TrackPoint> pts, {double unitM = 1000}) {
  final out = <WorkoutSplit>[];
  if (pts.length < 2) return out;
  var dist = 0.0, moving = 0.0;
  var splitStartDist = 0.0, splitStartTime = 0.0;
  double? splitStartAlt = pts.first.alt;
  double? lastAlt = pts.first.alt;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    if (b.alt != null) lastAlt = b.alt;
    if (a.segment != b.segment) continue;
    final d = haversine(a.lat, a.lon, b.lat, b.lon);
    final dt = b.t.difference(a.t).inMilliseconds / 1000;
    var segD = d, segT = dt;
    var fromAlt = a.alt;
    while (dist + segD >= splitStartDist + unitM && segD > 0) {
      final need = splitStartDist + unitM - dist;
      final f = need / segD;
      final tAt = moving + segT * f;
      final altAt = (fromAlt != null && b.alt != null)
          ? fromAlt + (b.alt! - fromAlt) * f
          : lastAlt;
      out.add(
        WorkoutSplit(
          index: out.length + 1,
          distanceM: unitM,
          seconds: tAt - splitStartTime,
          elevationDeltaM: (altAt ?? 0) - (splitStartAlt ?? altAt ?? 0),
        ),
      );
      dist += need;
      moving = tAt;
      segD -= need;
      segT -= segT * f;
      fromAlt = altAt;
      splitStartDist = dist;
      splitStartTime = moving;
      splitStartAlt = altAt;
    }
    dist += segD;
    moving += segT;
  }
  final rest = dist - splitStartDist;
  if (rest >= 10) {
    out.add(
      WorkoutSplit(
        index: out.length + 1,
        distanceM: rest,
        seconds: moving - splitStartTime,
        elevationDeltaM: (lastAlt ?? 0) - (splitStartAlt ?? lastAlt ?? 0),
      ),
    );
  }
  return out;
}

/// Năng lượng vận động ròng (kcal) theo môn:
/// - Đi bộ và chạy: phương trình chuyển hóa ACSM, 0,5 và 1,0 kcal mỗi kg mỗi km.
/// - Đạp xe: MET theo tốc độ trong Compendium of Physical Activities (2011): dưới 19 km/h 6,8 MET,
///   19–22 km/h 8,0 MET, từ 22 km/h 10,0 MET; năng lượng ròng = (MET − 1) × kg × giờ.
double workoutKcal({
  required Sport sport,
  required double distanceM,
  required double movingSeconds,
  required double weightKg,
}) {
  final km = distanceM / 1000;
  switch (sport) {
    case Sport.walk:
      return 0.5 * weightKg * km;
    case Sport.run:
      return 1.0 * weightKg * km;
    case Sport.ride:
      final hours = movingSeconds / 3600;
      if (hours <= 0) return 0;
      final kmh = km / hours;
      final met = kmh < 19
          ? 6.8
          : kmh < 22
          ? 8.0
          : 10.0;
      return (met - 1) * weightKg * hours;
  }
}

/// Mã hóa đường đi theo thuật toán Encoded Polyline của Google, độ chính xác 1e5.
String encodePolyline(List<(double, double)> coords) {
  final sb = StringBuffer();
  var prevLat = 0, prevLon = 0;
  void enc(int v) {
    var x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      sb.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    sb.writeCharCode(x + 63);
  }

  for (final (lat, lon) in coords) {
    final la = (lat * 1e5).round(), lo = (lon * 1e5).round();
    enc(la - prevLat);
    enc(lo - prevLon);
    prevLat = la;
    prevLon = lo;
  }
  return sb.toString();
}

/// Giải mã chuỗi Encoded Polyline thành danh sách (vĩ độ, kinh độ).
List<(double, double)> decodePolyline(String s) {
  final out = <(double, double)>[];
  var i = 0, lat = 0, lon = 0;
  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (i < s.length) {
    lat += next();
    lon += next();
    out.add((lat / 1e5, lon / 1e5));
  }
  return out;
}

/// Định dạng nhịp "m:ss" (giây cho mỗi km), ví dụ 330 → "5:30".
String formatPace(double? secPerKm) {
  if (secPerKm == null || secPerKm <= 0 || secPerKm.isInfinite) return '--:--';
  final s = secPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Định dạng thời lượng "h:mm:ss" hoặc "mm:ss".
String formatDuration(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
