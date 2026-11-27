import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';

import 'helpers/fake_backend.dart';

class _WorkoutRepo implements WorkoutRepository {
  _WorkoutRepo(this.items);
  final List<Workout> items;

  @override
  Future<void> delete(String id) async {}
  @override
  Future<Workout?> get(String id) async => null;
  @override
  Future<List<Workout>> list() async => items;
  @override
  Future<void> save(Workout workout) async {}
}

Workout _run10k() {
  final start = DateTime(2026, 11, 23, 7);
  return Workout(
    id: 'run-10k',
    sport: Sport.run,
    title: 'Bài chạy thử',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 60)),
    movingSeconds: 3600,
    distanceM: 10000,
    elevationGainM: 0,
    kcal: 600,
    splits: const [],
    points: const [],
    polyline: '',
  );
}

void main() {
  testWidgets('Tổng quan hiện Health Score, chuỗi ngày và thử thách tuần', (
    tester,
  ) async {
    await pumpApp(
      tester,
      providerOverrides: [
        workoutRepositoryProvider.overrideWithValue(_WorkoutRepo([])),
      ],
    );
    expect(find.text('Điểm sức khỏe'), findsOneWidget);
    expect(find.text('3 ngày liền'), findsOneWidget);
    expect(find.text('Uống đủ nước 5 ngày trong tuần'), findsOneWidget);
  });

  testWidgets('màn Huy hiệu: huy hiệu đã đạt và chưa đạt có nhãn Semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      providerOverrides: [
        workoutRepositoryProvider.overrideWithValue(_WorkoutRepo([])),
      ],
    );
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    router.push('/achievements');
    await tester.pumpAndSettle();
    expect(find.text('Đã đạt 1 trên 6'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Bước đầu tiên.*Đã đạt')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Một tuần bền bỉ.*Chưa đạt')),
      findsOneWidget,
    );
    expect(find.text('Buổi đầu tiên'), findsOneWidget);
    expect(find.text('Tuần 20 km'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('huy hiệu chạy cập nhật từ workout local', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      providerOverrides: [
        workoutRepositoryProvider.overrideWithValue(_WorkoutRepo([_run10k()])),
      ],
    );
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    router.push('/achievements');
    await tester.pumpAndSettle();

    expect(find.text('Đã đạt 4 trên 6'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Chạy 10 km.*Đã đạt')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tuần 20 km.*Chưa đạt')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
