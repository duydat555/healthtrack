import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/main.dart';
import 'package:integration_test/integration_test.dart';

/// Đo hiệu năng màn Tổng quan (issue #66): số lần rebuild widget và thời gian build/raster
/// của từng khung hình khi cuộn. Chạy trên Simulator hoặc máy thật:
///   cd mobile && flutter test integration_test/dashboard_perf_test.dart -d THIET_BI
/// Lưu ý: chế độ debug chậm hơn profile/release nhiều lần; Simulator không hỗ trợ profile,
/// nên số đo tuyệt đối chỉ dùng để so sánh tương đối. Số lần rebuild thì không phụ thuộc chế độ.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cuộn Tổng quan không rebuild thừa và khung hình ổn định', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HealthTrackApp()));
    await tester.pumpAndSettle(
      const Duration(seconds: 3),
    ); // chờ hoạt ảnh vào màn xong

    final rebuilds = <String, int>{};
    final timings = <FrameTiming>[];
    void onTimings(List<FrameTiming> t) => timings.addAll(t);

    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final name = element.widget.runtimeType.toString();
      rebuilds[name] = (rebuilds[name] ?? 0) + 1;
    };
    SchedulerBinding.instance.addTimingsCallback(onTimings);

    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 3; i++) {
      await tester.fling(list, const Offset(0, -500), 1500);
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, 500), 1500);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 1));

    debugOnRebuildDirtyWidget = null;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);

    // Các widget nặng không được rebuild khi chỉ cuộn (chúng không phụ thuộc vào vị trí cuộn)
    for (final heavy in [
      'HomeScreen',
      '_RingsCard',
      'ActivityRings',
      'MetricCard',
      '_WeekChart',
    ]) {
      expect(rebuilds[heavy] ?? 0, 0, reason: '$heavy bị rebuild khi cuộn');
    }

    final build =
        timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final raster =
        timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    double pct(List<double> v, double p) =>
        v.isEmpty ? 0 : v[((v.length - 1) * p).round()];
    final totalRebuilds = rebuilds.values.fold<int>(0, (a, b) => a + b);

    // ignore: avoid_print
    print(
      'PERF frames=${timings.length} '
      'build_ms p50=${pct(build, .5).toStringAsFixed(2)} p90=${pct(build, .9).toStringAsFixed(2)} '
      'max=${pct(build, 1).toStringAsFixed(2)} | '
      'raster_ms p50=${pct(raster, .5).toStringAsFixed(2)} p90=${pct(raster, .9).toStringAsFixed(2)} '
      'max=${pct(raster, 1).toStringAsFixed(2)} | rebuilds_total=$totalRebuilds',
    );
    // ignore: avoid_print
    print(
      'PERF rebuilds by widget: ${(rebuilds.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).map((e) => '${e.key}=${e.value}').join(', ')}',
    );

    expect(timings, isNotEmpty);
  });
}
