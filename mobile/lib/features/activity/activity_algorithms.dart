import 'dart:math' as math;

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

/// Số ô 15 phút trong một "ngày ngủ" (16:00 hôm trước tới 15:59 hôm sau), như SensibleSleep.
const sleepBins = 96;
const _binMinutes = 15;

/// Tiên nghiệm về giờ ngủ và giờ dậy, tính bằng chỉ số ô kể từ 16:00 (ô 28 là 23:00, ô 60 là 07:00).
@immutable
class SleepPrior {
  const SleepPrior({this.sleepBin = 28, this.wakeBin = 60, this.sdBins = 8});

  final double sleepBin;
  final double wakeBin;

  /// Độ lệch chuẩn (ô): 8 ô = 2 giờ khi chưa biết thói quen, hẹp lại khi đã có lịch sử.
  final double sdBins;

  /// Cá nhân hóa từ các giấc ngủ gần đây (ít nhất 3): lấy trung vị giờ ngủ và giờ dậy.
  static SleepPrior fromHistory(List<(DateTime, DateTime)> sleeps) {
    if (sleeps.length < 3) return const SleepPrior();
    double bin(DateTime t) {
      var m = (t.hour - 16) * 60 + t.minute;
      if (m < 0) m += 24 * 60;
      return m / _binMinutes;
    }

    double median(List<double> v) {
      v.sort();
      final mid = v.length ~/ 2;
      return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
    }

    return SleepPrior(
      sleepBin: median([for (final s in sleeps) bin(s.$1)]),
      wakeBin: median([for (final s in sleeps) bin(s.$2)]),
      sdBins: 6,
    );
  }
}

/// Ước lượng giấc ngủ của đêm trước ngày [wakeDay] theo mô hình SensibleSleep (Cuttone và cộng sự,
/// PLOS ONE 2017, độ chính xác 0,89 so với vòng đeo tay đo giấc ngủ).
///
/// [events] là thời điểm người dùng "thức và dùng máy": iOS là lúc máy bắt đầu chuyển động
/// (CoreMotion), Android là lúc mở màn hình. Mô hình:
/// - Chia 16:00 hôm trước tới 15:59 ngày [wakeDay] thành 96 ô 15 phút, đếm sự kiện mỗi ô.
/// - Số sự kiện mỗi ô theo phân phối Poisson: lúc ngủ tỉ lệ rất thấp, lúc thức bằng trung bình
///   các ô thức (ước lượng hợp lý cực đại).
/// - Giờ ngủ, giờ dậy có tiên nghiệm chuẩn quanh [prior] (mặc định 23:00 và 07:00).
/// - Bài báo dùng MCMC; ở đây chỉ có 96×96 cặp nên duyệt hết và lấy cặp có hậu nghiệm lớn nhất,
///   cho cùng điểm tối ưu và chạy tức thì trên máy.
///
/// Trả null khi chưa đủ dữ liệu, khi không có quãng nào gần như không dùng máy đủ 3 giờ, hoặc khi
/// chưa thấy dấu hiệu thức dậy (đêm còn đang diễn ra).
SleepEstimate? estimateSleep(
  List<DateTime> events, {
  required DateTime wakeDay,
  SleepPrior prior = const SleepPrior(),
  DateTime? now,
  int minBins = 12, // 3 giờ
  int maxBins = 56, // 14 giờ
  double sleepRate = 0.05,
}) {
  final day = DateTime(wakeDay.year, wakeDay.month, wakeDay.day);
  final start = day.subtract(const Duration(hours: 8));
  final limit = now ?? day.add(const Duration(hours: 16));
  final observed = (limit.difference(start).inMinutes ~/ _binMinutes).clamp(
    0,
    sleepBins,
  );
  if (observed < minBins + 4) return null;

  final counts = List<int>.filled(observed, 0);
  for (final e in events) {
    final i = e.difference(start).inMinutes ~/ _binMinutes;
    if (!e.isBefore(start) && i < observed) counts[i]++;
  }
  final total = counts.fold<int>(0, (a, b) => a + b);
  if (total < 5) return null;

  // Tổng tiền tố để tính tổng sự kiện trong một khoảng bất kỳ trong O(1)
  final prefix = List<int>.filled(observed + 1, 0);
  for (var i = 0; i < observed; i++) {
    prefix[i + 1] = prefix[i] + counts[i];
  }

  double logNormal(double x, double mu, double sd) =>
      -0.5 * ((x - mu) / sd) * ((x - mu) / sd);

  final lnSleep = math.log(sleepRate);
  var best = double.negativeInfinity;
  (int, int)? bestPair;
  for (var s = 0; s < observed; s++) {
    for (var w = s + minBins; w <= s + maxBins && w < observed; w++) {
      // Phải có hoạt động sau giờ dậy, nếu không có thể người dùng vẫn đang ngủ
      if (prefix[observed] - prefix[w] == 0) continue;
      final kSleep = prefix[w] - prefix[s];
      final nSleep = w - s;
      // Trong giấc ngủ gần như không dùng máy: tối đa 1 lần cộng 1 lần mỗi 2,5 giờ
      if (kSleep > 1 + 0.1 * nSleep) continue;
      final kAwake = total - kSleep;
      final nAwake = observed - nSleep;
      final lambdaAwake = math.max(kAwake / nAwake, 0.2);
      final ll =
          kSleep * lnSleep -
          sleepRate * nSleep +
          kAwake * math.log(lambdaAwake) -
          lambdaAwake * nAwake +
          logNormal(s.toDouble(), prior.sleepBin, prior.sdBins) +
          logNormal(w.toDouble(), prior.wakeBin, prior.sdBins);
      if (ll > best) {
        best = ll;
        bestPair = (s, w);
      }
    }
  }
  if (bestPair == null) return null;
  const bin = Duration(minutes: _binMinutes);
  return SleepEstimate(
    start.add(bin * bestPair.$1),
    start.add(bin * bestPair.$2),
  );
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

/// Bước chân trong một khoảng thời gian ngắn (iOS lấy từ CMPedometer theo từng 15 phút).
@immutable
class StepBucket {
  const StepBucket({
    required this.start,
    required this.steps,
    this.distanceM,
    this.paceSecPerM,
  });

  final DateTime start;
  final int steps;
  final double? distanceM;

  /// Nhịp trung bình lúc đang di chuyển (giây/mét) do Apple đo; null nếu không có.
  final double? paceSecPerM;
}

/// Tốc độ từ đó coi là chạy (m/s), khoảng 8 km/h: phương trình ACSM cho chạy áp dụng từ đây.
const runningSpeed = 2.2;

/// Năng lượng vận động ròng theo phương trình chuyển hóa của ACSM (ACSM's Guidelines for Exercise
/// Testing and Prescription): thành phần ngang của VO2 là 0,1 mL/kg/m khi đi bộ và 0,2 mL/kg/m khi
/// chạy; 1 lít O2 khoảng 5 kcal. Vậy mỗi km tốn 0,5 kcal/kg khi đi và 1,0 kcal/kg khi chạy.
double netKcalPerKm(double weightKg, {required bool running}) =>
    (running ? 0.2 : 0.1) * 1000 / 1000 * 5 * weightKg;

/// Ước lượng năng lượng tiêu hao hôm nay:
/// - Nghỉ: BMR (Mifflin-St Jeor) nhân phần ngày đã trôi qua.
/// - Vận động: nếu có số liệu của Apple ([appleActiveKcal], từ Apple Health) thì dùng luôn. Nếu
///   không, cộng từng khoảng trong [buckets] theo ACSM, phân biệt đi/chạy bằng tốc độ Apple đo được;
///   số bước chưa nằm trong khoảng nào tính như đi bộ, quãng đường bằng số bước nhân chiều dài bước.
EnergyEstimate estimateEnergy({
  required int steps,
  required BodyProfile profile,
  required DateTime now,
  double? distanceM,
  List<StepBucket> buckets = const [],
  double? appleActiveKcal,
}) {
  final midnight = DateTime(now.year, now.month, now.day);
  final dayFraction = now.difference(midnight).inSeconds / 86400;
  final stride = strideMeters(profile);

  var km = 0.0;
  var active = 0.0;
  var covered = 0;
  for (final b in buckets) {
    final bKm = (b.distanceM ?? b.steps * stride) / 1000;
    final pace = b.paceSecPerM;
    final running = pace != null && pace > 0 && 1 / pace >= runningSpeed;
    km += bKm;
    active += bKm * netKcalPerKm(profile.weight, running: running);
    covered += b.steps;
  }
  final rest = steps - covered;
  if (rest > 0) {
    // Có quãng đường tổng do cảm biến đo mà không chia khoảng thì dùng nó cho phần còn lại
    final restKm = buckets.isEmpty && distanceM != null
        ? distanceM / 1000
        : rest * stride / 1000;
    km += restKm;
    active += restKm * netKcalPerKm(profile.weight, running: false);
  }
  return EnergyEstimate(
    restingKcal: basalMetabolicRate(profile, now) * dayFraction,
    activeKcal: appleActiveKcal ?? active,
    distanceKm: km,
  );
}
