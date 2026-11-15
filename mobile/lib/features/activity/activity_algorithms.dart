import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter/foundation.dart';

/// Thuật toán ước lượng từ dữ liệu cảm biến của máy, không cần Apple Health. Tất cả là hàm thuần
/// để kiểm thử được mà không cần thiết bị.

/// Một giấc ngủ ước lượng.
@immutable
class SleepEstimate {
  const SleepEstimate(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is SleepEstimate && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SleepEstimate($start → $end)';
}

/// Ước lượng giấc ngủ chính của đêm trước ngày [wakeDay] từ các quãng nghỉ (iOS: máy nằm yên,
/// Android: màn hình tắt).
///
/// 1. Chỉ xét cửa sổ từ 18:00 hôm trước tới 14:00 ngày [wakeDay].
/// 2. Gộp các quãng cách nhau không quá [maxGap] (dậy đi vệ sinh, liếc điện thoại).
/// 3. Bỏ khối ngắn hơn [minSleep]; khối dài quá 14 giờ bị cắt còn 14 giờ tính từ đầu khối
///    (thường là máy để quên, không phải ngủ).
/// 4. Ưu tiên khối chạm khung 0:00–6:00 (giờ ngủ phổ biến), trong đó chọn khối dài nhất;
///    không có thì lấy khối dài nhất.
/// 5. Trừ [fallAsleep] ở đầu khối: lúc vừa đặt máy xuống thường chưa ngủ ngay.
SleepEstimate? estimateSleep(
  List<RestInterval> rest, {
  required DateTime wakeDay,
  Duration maxGap = const Duration(minutes: 20),
  Duration minSleep = const Duration(hours: 3),
  Duration fallAsleep = const Duration(minutes: 10),
}) {
  final day = DateTime(wakeDay.year, wakeDay.month, wakeDay.day);
  final windowStart = day.subtract(const Duration(hours: 6));
  final windowEnd = day.add(const Duration(hours: 14));

  final clipped = <(DateTime, DateTime)>[];
  for (final r in rest) {
    final s = r.start.isBefore(windowStart) ? windowStart : r.start;
    final e = r.end.isAfter(windowEnd) ? windowEnd : r.end;
    if (e.isAfter(s)) clipped.add((s, e));
  }
  if (clipped.isEmpty) return null;
  clipped.sort((a, b) => a.$1.compareTo(b.$1));

  final blocks = <(DateTime, DateTime)>[clipped.first];
  for (final (s, e) in clipped.skip(1)) {
    final (bs, be) = blocks.last;
    if (!s.isAfter(be.add(maxGap))) {
      blocks[blocks.length - 1] = (bs, e.isAfter(be) ? e : be);
    } else {
      blocks.add((s, e));
    }
  }

  const maxSleep = Duration(hours: 14);
  final candidates = [
    for (final (s, e) in blocks)
      if (e.difference(s) >= minSleep)
        (s, e.difference(s) > maxSleep ? s.add(maxSleep) : e),
  ];
  if (candidates.isEmpty) return null;

  final night = (day, day.add(const Duration(hours: 6)));
  bool touchesNight((DateTime, DateTime) b) =>
      b.$1.isBefore(night.$2) && b.$2.isAfter(night.$1);
  final preferred = candidates.where(touchesNight).toList();
  final pool = preferred.isNotEmpty ? preferred : candidates;
  pool.sort((a, b) => b.$2.difference(b.$1).compareTo(a.$2.difference(a.$1)));
  final (start, end) = pool.first;
  final asleep = start.add(fallAsleep);
  return SleepEstimate(asleep.isBefore(end) ? asleep : start, end);
}

/// Thông tin cơ thể dùng để tính năng lượng; thiếu thì dùng giá trị trung bình người lớn.
@immutable
class BodyProfile {
  const BodyProfile({
    this.weightKg,
    this.heightCm,
    this.birthDate,
    this.gender,
  });

  final double? weightKg;
  final double? heightCm;
  final DateTime? birthDate;

  /// `male`, `female` hoặc khác/không rõ.
  final String? gender;

  static const defaultWeightKg = 60.0;
  static const defaultHeightCm = 165.0;
  static const defaultAge = 25;

  double get weight => weightKg ?? defaultWeightKg;
  double get height => heightCm ?? defaultHeightCm;

  int ageAt(DateTime now) {
    final b = birthDate;
    if (b == null) return defaultAge;
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age.clamp(10, 100);
  }
}

/// Năng lượng tiêu hao trong ngày tính đến thời điểm hiện tại.
@immutable
class EnergyEstimate {
  const EnergyEstimate({
    required this.restingKcal,
    required this.activeKcal,
    required this.distanceKm,
  });

  /// Phần cơ thể tự đốt khi nghỉ (BMR) từ 0 giờ tới bây giờ.
  final double restingKcal;

  /// Phần đốt thêm do đi bộ.
  final double activeKcal;
  final double distanceKm;

  double get totalKcal => restingKcal + activeKcal;
}

/// Chiều dài bước chân (mét) theo chiều cao: khoảng 41,5% chiều cao ở nam và 41,3% ở nữ.
double strideMeters(BodyProfile p) {
  final ratio = switch (p.gender) {
    'male' => 0.415,
    'female' => 0.413,
    _ => 0.414,
  };
  return p.height * ratio / 100;
}

/// Tỉ lệ trao đổi chất cơ bản (kcal/ngày) theo công thức Mifflin-St Jeor.
double basalMetabolicRate(BodyProfile p, DateTime now) {
  final base = 10 * p.weight + 6.25 * p.height - 5 * p.ageAt(now);
  return switch (p.gender) {
    'male' => base + 5,
    'female' => base - 161,
    _ => base - 78, // trung bình hai giới
  };
}

/// Ước lượng năng lượng tiêu hao hôm nay:
/// - Nghỉ: BMR nhân phần ngày đã trôi qua.
/// - Đi bộ: khoảng 0,5 kcal cho mỗi kg cân nặng trên mỗi km (chi phí ròng của đi bộ). Quãng đường
///   lấy từ cảm biến nếu có ([distanceM]), không thì bằng số bước nhân chiều dài bước.
EnergyEstimate estimateEnergy({
  required int steps,
  required BodyProfile profile,
  required DateTime now,
  double? distanceM,
}) {
  final midnight = DateTime(now.year, now.month, now.day);
  final dayFraction = now.difference(midnight).inSeconds / 86400;
  final km = (distanceM ?? steps * strideMeters(profile)) / 1000;
  return EnergyEstimate(
    restingKcal: basalMetabolicRate(profile, now) * dayFraction,
    activeKcal: 0.5 * profile.weight * km,
    distanceKm: km,
  );
}
