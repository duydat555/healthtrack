import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/workout/sample_workout_repository.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_history_screen.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';
import 'package:healthtrack/features/workout/workout_summary_screen.dart';
import 'package:route_tracker/route_tracker.dart';

import 'helpers/fake_backend.dart';
import 'helpers/workout_history_data.dart';

class _FailOnceRepository extends SampleWorkoutRepository {
  _FailOnceRepository() : super([]);

  bool _fail = true;

  @override
  Future<List<Workout>> list() {
    if (_fail) {
      _fail = false;
      return Future.error(StateError('Lỗi đọc dữ liệu mẫu'));
    }
    return super.list();
  }
}

Future<void> openHistory(
  WidgetTester tester,
  WorkoutRepository repository,
) async {
  await pumpApp(
    tester,
    providerOverrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final entry = find.text('Lịch sử hoạt động');
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
}

void main() {
  testWidgets('mở từ Tổng quan, vẽ polyline, lọc từng môn và mở đúng buổi', (
    tester,
  ) async {
    const channel = MethodChannel('healthtrack/route');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Mở trang tổng kết với bản đồ dự phòng trong môi trường widget test.
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final now = DateTime.now();
    await openHistory(
      tester,
      SampleWorkoutRepository([
        historyWorkout('run', Sport.run, now, 1000),
        historyWorkout('walk', Sport.walk, now, 2000),
        historyWorkout('ride', Sport.ride, now, 3000),
      ]),
    );

    expect(find.text('Tuần này'), findsOneWidget);
    expect(find.text('Tháng này'), findsOneWidget);
    expect(find.text('6 km'), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is RoutePainter,
      ),
      findsNWidgets(3),
    );

    for (final sport in Sport.values) {
      await tester.tap(find.widgetWithText(ChoiceChip, sport.label));
      await tester.pumpAndSettle();
      for (final item in Sport.values) {
        expect(
          find.text('Buổi mẫu ${item.name}'),
          item == sport ? findsOneWidget : findsNothing,
        );
      }
      expect(find.text('6 km'), findsNWidgets(2));
    }

    await tester.tap(find.text('Buổi mẫu ride'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WorkoutSummaryScreen>(find.byType(WorkoutSummaryScreen)).id,
      'ride',
    );
    expect(find.text('Buổi mẫu ride'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Buổi mẫu run'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Buổi mẫu run'), findsOneWidget);
  });

  testWidgets(
    'thử lại sau lỗi repository và hiện trạng thái chưa có buổi tập',
    (tester) async {
      await openHistory(tester, _FailOnceRepository());
      expect(find.text('Không tải được lịch sử hoạt động.'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chưa có buổi tập nào.'), findsOneWidget);
      expect(find.text('Ghi hoạt động'), findsOneWidget);
      expect(find.text('0 km'), findsNWidgets(2));
    },
  );

  testWidgets(
    'hiện trạng thái bộ lọc rỗng và không tràn ở cỡ iPhone SE/Pro Max sáng/tối',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final size in [const Size(375, 667), const Size(430, 932)]) {
        tester.view.physicalSize = size;
        for (final brightness in Brightness.values) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await openHistory(
            tester,
            SampleWorkoutRepository([
              historyWorkout('run', Sport.run, DateTime.now(), 1000),
            ]),
          );
          await tester.tap(find.widgetWithText(ChoiceChip, Sport.walk.label));
          await tester.pumpAndSettle();
          expect(find.text('Chưa có buổi tập cho môn này.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );
}
