import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/activity/activity_algorithms.dart';

DateTime t(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);

/// Sự kiện "đang thức": 2 sự kiện mỗi 15 phút trong các khoảng [from, to).
List<DateTime> busy(List<(DateTime, DateTime)> ranges) => [
  for (final (from, to) in ranges)
    for (
      var x = from;
      x.isBefore(to);
      x = x.add(const Duration(minutes: 15))
    ) ...[x.add(const Duration(minutes: 2)), x.add(const Duration(minutes: 9))],
];

void main() {
  group('estimateSleep (SensibleSleep)', () {
    test('đêm bình thường: ngủ 23:00, dậy 07:00, một lần cầm máy lúc 3 giờ không làm gãy giấc', () {
      final events = [
        ...busy([(t(14, 16), t(14, 23)), (t(15, 7), t(15, 12))]),
        t(15, 3, 5),
      ];
      final est = estimateSleep(
        events,
        wakeDay: DateTime(2026, 11, 15),
        now: t(15, 12),
      );
      expect(est!.start, t(14, 23));
      expect(est.end, t(15, 7));
    });

    test('ngủ muộn 01:30 dậy 09:30: dữ liệu thắng tiên nghiệm 23:00/07:00', () {
      final est = estimateSleep(
        busy([(t(14, 16), t(15, 1, 30)), (t(15, 9, 30), t(15, 14))]),
        wakeDay: DateTime(2026, 11, 15),
        now: t(15, 14),
      );
      expect(est!.start, t(15, 1, 30));
      expect(est.end, t(15, 9, 30));
    });

    test(
      'đêm chưa kết thúc (chưa thấy hoạt động sau giờ dậy) thì chưa đoán',
      () {
        expect(
          estimateSleep(
            busy([(t(14, 16), t(14, 23))]),
            wakeDay: DateTime(2026, 11, 15),
            now: t(15, 5),
          ),
          isNull,
        );
      },
    );

    test('quá ít dữ liệu thì không đoán', () {
      expect(
        estimateSleep(
          [t(14, 18), t(15, 8)],
          wakeDay: DateTime(2026, 11, 15),
          now: t(15, 12),
        ),
        isNull,
      );
    });

    test('tiên nghiệm cá nhân lấy trung vị lịch sử', () {
      final prior = SleepPrior.fromHistory([
        (t(10, 0), t(10, 8)),
        (t(11, 0, 30), t(11, 8, 30)),
        (t(11, 23, 30), t(12, 7, 30)),
      ]);
      expect(prior.sleepBin, 32); // 00:00 = 8 giờ sau 16:00
      expect(prior.wakeBin, 64); // 08:00
      expect(prior.sdBins, 6);
      expect(SleepPrior.fromHistory(const []).sleepBin, 28);
    });
  });

  group('năng lượng', () {
    const male = BodyProfile(weightKg: 70, heightCm: 175, gender: 'male');

    test(
      'BMR Mifflin-St Jeor: nam 70 kg, 175 cm, 25 tuổi khoảng 1674 kcal',
      () {
        final p = BodyProfile(
          weightKg: 70,
          heightCm: 175,
          gender: 'male',
          birthDate: DateTime(2001, 1, 1),
        );
        expect(
          basalMetabolicRate(p, DateTime(2026, 11, 15)),
          closeTo(1673.75, 0.01),
        );
      },
    );

    test('chiều dài bước theo chiều cao và giới tính', () {
      expect(strideMeters(male), closeTo(0.726, 0.001));
      expect(
        strideMeters(const BodyProfile(heightCm: 160, gender: 'female')),
        closeTo(0.661, 0.001),
      );
    });

    test('ACSM: đi bộ 0,5 kcal/kg/km, chạy 1,0 kcal/kg/km', () {
      expect(netKcalPerKm(70, running: false), closeTo(35, 1e-9));
      expect(netKcalPerKm(70, running: true), closeTo(70, 1e-9));
    });

    test(
      'khoảng chạy (tốc độ Apple đo ≥ 2,2 m/s) tính gấp đôi khoảng đi bộ',
      () {
        final now = DateTime(2026, 11, 15, 12);
        final e = estimateEnergy(
          steps: 3000,
          profile: male,
          now: now,
          buckets: [
            StepBucket(
              start: t(15, 7),
              steps: 1500,
              distanceM: 1000,
              paceSecPerM: 0.8,
            ), // 1,25 m/s
            StepBucket(
              start: t(15, 8),
              steps: 1500,
              distanceM: 2000,
              paceSecPerM: 0.4,
            ), // 2,5 m/s
          ],
        );
        expect(e.distanceKm, closeTo(3, 1e-9));
        expect(e.activeKcal, closeTo(35 + 140, 1e-9));
      },
    );

    test('số liệu của Apple Health được dùng thay cho ước lượng', () {
      final e = estimateEnergy(
        steps: 10000,
        profile: male,
        now: DateTime(2026, 11, 15, 12),
        appleActiveKcal: 412,
      );
      expect(e.activeKcal, 412);
    });

    test('không có khoảng chi tiết (Android): đi bộ theo chiều dài bước', () {
      final e = estimateEnergy(
        steps: 10000,
        profile: male,
        now: DateTime(2026, 11, 15, 12),
      );
      expect(e.distanceKm, closeTo(7.2625, 0.001));
      expect(e.activeKcal, closeTo(0.5 * 70 * 7.2625, 0.01));
      expect(
        e.restingKcal,
        closeTo(basalMetabolicRate(male, DateTime(2026, 11, 15)) / 2, 0.5),
      );
    });
  });
}
