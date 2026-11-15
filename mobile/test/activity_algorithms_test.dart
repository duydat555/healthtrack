import 'package:activity_sensors/activity_sensors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/activity/activity_algorithms.dart';

DateTime t(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);
RestInterval r(DateTime s, DateTime e) => RestInterval(s, e);

void main() {
  group('estimateSleep', () {
    test(
      'gộp các quãng nghỉ cách nhau ngắn thành một giấc, trừ 10 phút chưa ngủ',
      () {
        final est = estimateSleep([
          r(t(14, 23, 5), t(15, 2, 0)),
          r(t(15, 2, 12), t(15, 6, 40)), // dậy 12 phút giữa đêm
        ], wakeDay: DateTime(2026, 11, 15));
        expect(est, SleepEstimate(t(14, 23, 15), t(15, 6, 40)));
      },
    );

    test('bỏ quãng nghỉ ngắn ban ngày và chọn khối chạm khung 0–6 giờ', () {
      final est = estimateSleep([
        r(t(14, 19, 0), t(14, 22, 30)), // xem phim 3,5 giờ buổi tối
        r(t(15, 0, 30), t(15, 4, 0)), // ngủ muộn, chỉ 3,5 giờ
        r(t(15, 9, 0), t(15, 9, 40)),
      ], wakeDay: DateTime(2026, 11, 15));
      expect(est!.start, t(15, 0, 40));
      expect(est.end, t(15, 4, 0));
    });

    test('không có khối nào đủ 3 giờ thì không đoán', () {
      expect(
        estimateSleep([
          r(t(14, 23, 0), t(15, 1, 0)),
          r(t(15, 2, 0), t(15, 3, 30)),
        ], wakeDay: DateTime(2026, 11, 15)),
        isNull,
      );
    });

    test(
      'chỉ xét cửa sổ 18:00 hôm trước tới 14:00, máy để quên bị cắt còn 14 giờ',
      () {
        final est = estimateSleep([
          r(t(13, 10, 0), t(15, 20, 0)), // nằm yên hai ngày
        ], wakeDay: DateTime(2026, 11, 15));
        // Cửa sổ 14/11 18:00 → 15/11 14:00 (20 giờ), cắt còn 14 giờ tính từ đầu
        expect(est!.start, t(14, 18, 10));
        expect(est.end, t(15, 8, 0));
      },
    );
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

    test('10.000 bước lúc 12 giờ trưa: nửa BMR cộng phần đi bộ', () {
      final e = estimateEnergy(
        steps: 10000,
        profile: male,
        now: DateTime(2026, 11, 15, 12),
      );
      expect(e.distanceKm, closeTo(7.26, 0.01));
      expect(e.activeKcal, closeTo(0.5 * 70 * 7.2625, 0.1));
      expect(
        e.restingKcal,
        closeTo(basalMetabolicRate(male, DateTime(2026, 11, 15)) / 2, 0.5),
      );
    });

    test('ưu tiên quãng đường đo được từ cảm biến', () {
      final e = estimateEnergy(
        steps: 10000,
        profile: male,
        now: DateTime(2026, 11, 15, 12),
        distanceM: 8000,
      );
      expect(e.distanceKm, 8);
      expect(e.activeKcal, closeTo(280, 0.01));
    });

    test('thiếu hồ sơ thì dùng giá trị trung bình, không lỗi', () {
      final e = estimateEnergy(
        steps: 0,
        profile: const BodyProfile(),
        now: DateTime(2026, 11, 15, 6),
      );
      expect(e.activeKcal, 0);
      expect(e.restingKcal, greaterThan(300));
    });
  });
}
