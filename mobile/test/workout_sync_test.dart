import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:healthtrack/features/workout/workout_repository.dart';
import 'package:healthtrack/features/workout/workout_sync.dart';

import 'helpers/fake_backend.dart';

Workout fixture(String id) => Workout.fromJson(
  jsonDecode(File('test/fixtures/workouts/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Máy chủ giả: có thể "mất mạng" hoặc từ chối.
class FakeRemote implements WorkoutRepository {
  final items = <String, Workout>{};
  Object? failWith;
  int saves = 0;

  void _check() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<Workout>> list() async {
    _check();
    // Danh sách thật không kèm điểm GPS
    return [
      for (final w in items.values)
        Workout.fromJson(w.toJson(withPoints: false)),
    ];
  }

  @override
  Future<Workout?> get(String id) async {
    _check();
    return items[id];
  }

  @override
  Future<void> save(Workout w) async {
    _check();
    saves++;
    items[w.id] = w;
  }

  @override
  Future<void> delete(String id) async {
    _check();
    items.remove(id);
  }
}

DioException offline() => DioException(
  requestOptions: RequestOptions(path: '/workouts'),
  type: DioExceptionType.connectionError,
);

DioException rejected(int code) => DioException(
  requestOptions: RequestOptions(path: '/workouts'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/workouts'),
    statusCode: code,
  ),
);

void main() {
  late Directory dir;
  late LocalWorkoutRepository local;
  late FakeRemote remote;
  late MemorySyncStateStore store;
  late SyncedWorkoutRepository repo;
  var changes = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sync');
    local = LocalWorkoutRepository(baseDir: () async => dir);
    remote = FakeRemote();
    store = MemorySyncStateStore();
    changes = 0;
    repo = SyncedWorkoutRepository(
      local: local,
      remote: remote,
      store: store,
      onChanged: () => changes++,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('lưu: có ngay trên máy, rồi lên máy chủ', () async {
    final w = fixture('sample-run-han-river');
    await repo.save(w);
    expect((await repo.list()).single.id, w.id);
    await repo.sync();
    expect(remote.items.keys, [w.id]);
    expect(store.state.pending, isEmpty);
    expect(store.state.synced, contains(w.id));
  });

  test('mất mạng: vẫn lưu được, đẩy lên ở lần đồng bộ sau', () async {
    remote.failWith = offline();
    final w = fixture('sample-walk-vku');
    await repo.save(w);
    await repo.sync();
    expect((await repo.list()).single.id, w.id);
    expect(remote.items, isEmpty);
    expect(store.state.pending[w.id], 'put');

    remote.failWith = null;
    await repo.sync();
    expect(remote.items.keys, [w.id]);
    expect(store.state.pending, isEmpty);
  });

  test('máy chủ từ chối hẳn (422): bỏ việc chờ, không thử mãi', () async {
    remote.failWith = rejected(422);
    await repo.save(fixture('sample-walk-vku'));
    await repo.sync();
    expect(store.state.pending, isEmpty);
    expect(await repo.list(), hasLength(1)); // dữ liệu trên máy còn nguyên
  });

  test('hết phiên (401) thì giữ việc chờ', () async {
    remote.failWith = rejected(401);
    await repo.save(fixture('sample-walk-vku'));
    await repo.sync();
    expect(store.state.pending, hasLength(1));
  });

  test('xóa: xóa ở máy rồi xóa trên máy chủ', () async {
    final w = fixture('sample-run-han-river');
    await repo.save(w);
    await repo.sync();
    await repo.delete(w.id);
    expect(await repo.list(), isEmpty);
    await repo.sync();
    expect(remote.items, isEmpty);
    expect(store.state.pending, isEmpty);
    expect(store.state.synced, isEmpty);
  });

  test('tải về buổi tập ghi ở máy khác, đủ điểm GPS', () async {
    final w = fixture('sample-ride-my-khe');
    remote.items[w.id] = w;
    await repo.sync();
    final got = (await local.get(w.id))!;
    expect(got.points, hasLength(w.points.length));
    expect(changes, 1);
  });

  test('buổi đã xóa ở máy khác thì xóa luôn ở đây', () async {
    final w = fixture('sample-run-han-river');
    await repo.save(w);
    await repo.sync();
    remote.items.clear(); // xóa ở máy khác
    await repo.sync();
    expect(await repo.list(), isEmpty);
    expect(changes, 1);
  });

  test(
    'buổi chưa từng lên máy chủ (ghi lúc chưa đăng nhập) được đẩy lên',
    () async {
      final w = fixture('sample-walk-vku');
      await local.save(w); // ghi thẳng vào máy, không qua đồng bộ
      await repo.sync();
      expect(remote.items.keys, [w.id]);
      expect(
        await repo.list(),
        hasLength(1),
      ); // không bị coi là "đã xóa ở máy khác"
    },
  );

  test('đồng bộ hai lần liên tiếp không đẩy trùng', () async {
    await repo.save(fixture('sample-walk-vku'));
    await repo.sync();
    final n = remote.saves;
    await repo.sync();
    expect(remote.saves, n);
  });

  group('ApiWorkoutRepository', () {
    test('PUT, GET một buổi, danh sách, DELETE 404 coi như xong', () async {
      final w = fixture('sample-run-han-river');
      final slim = Map<String, Object?>.of(w.toJson(withPoints: false));
      final backend = FakeBackend({
        'PUT /workouts/${w.id}': (o) {
          expect((o.data as Map)['id'], w.id);
          return const FakeResponse(201, {});
        },
        'GET /workouts': (o) => FakeResponse(200, [slim]),
        'GET /workouts/${w.id}': (_) => FakeResponse(200, w.toJson()),
        'DELETE /workouts/${w.id}': (_) =>
            const FakeResponse(404, {'detail': 'x'}),
        'GET /workouts/none': (_) => const FakeResponse(404, {'detail': 'x'}),
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = backend;
      final api = ApiWorkoutRepository(dio);
      await api.save(w);
      expect((await api.list()).single.id, w.id);
      expect((await api.get(w.id))!.points, hasLength(w.points.length));
      expect(await api.get('none'), isNull);
      await api.delete(w.id); // 404 không ném lỗi
      expect(backend.count('PUT /workouts/${w.id}'), 1);
    });
  });
}
