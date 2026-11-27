import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import 'workout.dart';
import 'workout_repository.dart';

/// Buổi tập lưu trên máy chủ qua API `/workouts` (docs/14). Danh sách không kèm điểm GPS; muốn
/// đủ điểm thì gọi [get].
class ApiWorkoutRepository implements WorkoutRepository {
  ApiWorkoutRepository(this._dio);

  final Dio _dio;

  static const pageSize = 100;
  static const _maxPages = 20;

  @override
  Future<List<Workout>> list() async {
    final out = <Workout>[];
    DateTime? before;
    for (var page = 0; page < _maxPages; page++) {
      final res = await _dio.get<List<dynamic>>(
        '/workouts',
        queryParameters: {
          'limit': pageSize,
          if (before != null) 'before': before.toUtc().toIso8601String(),
        },
      );
      final items = [
        for (final j in res.data ?? const [])
          Workout.fromJson((j as Map).cast<String, Object?>()),
      ];
      out.addAll(items);
      if (items.length < pageSize) break;
      before = items.last.startedAt;
    }
    return out;
  }

  @override
  Future<Workout?> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/workouts/$id');
      return Workout.fromJson(res.data!.cast<String, Object?>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> save(Workout workout) async {
    await _dio.put<void>('/workouts/${workout.id}', data: workout.toJson());
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/workouts/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow; // đã xóa rồi cũng coi là xong
    }
  }
}

/// Việc còn chờ đẩy lên máy chủ, và những buổi đã biết là có trên máy chủ.
class SyncState {
  SyncState({Set<String>? synced, Map<String, String>? pending})
    : synced = synced ?? {},
      pending = pending ?? {};

  /// Id đã có trên máy chủ. Có ở đây mà máy chủ không còn nghĩa là đã bị xóa ở máy khác.
  final Set<String> synced;

  /// id -> `put` (cần đẩy lên) hoặc `delete` (cần xóa trên máy chủ).
  final Map<String, String> pending;

  Map<String, Object?> toJson() => {
    'synced': synced.toList(),
    'pending': pending,
  };

  factory SyncState.fromJson(Map<String, Object?> j) => SyncState(
    synced: {for (final x in (j['synced'] as List?) ?? const []) x as String},
    pending: {
      for (final e in ((j['pending'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    },
  );
}

/// Nơi lưu [SyncState] giữa các lần mở app.
abstract class SyncStateStore {
  Future<SyncState> load();
  Future<void> save(SyncState state);
}

class FileSyncStateStore implements SyncStateStore {
  FileSyncStateStore(this._file);

  final Future<File> Function() _file;

  @override
  Future<SyncState> load() async {
    final f = await _file();
    if (!f.existsSync()) return SyncState();
    try {
      return SyncState.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, Object?>,
      );
    } on FormatException {
      return SyncState(); // file hỏng: đồng bộ lại từ đầu, không mất buổi tập nào
    }
  }

  @override
  Future<void> save(SyncState state) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(f.path);
  }
}

class MemorySyncStateStore implements SyncStateStore {
  SyncState state = SyncState();

  @override
  Future<SyncState> load() async => state;

  @override
  Future<void> save(SyncState s) async => state = s;
}

/// Lưu trên máy trước, đồng bộ với máy chủ sau. Ghi và xóa luôn thành công ở máy; việc đẩy lên
/// máy chủ chạy nền và được thử lại ở lần [sync] sau nếu mất mạng. Hai chiều: buổi tập ghi ở máy
/// khác được tải về, buổi tập xóa ở máy khác bị xóa ở đây.
class SyncedWorkoutRepository implements WorkoutRepository {
  SyncedWorkoutRepository({
    required this.local,
    required this.remote,
    required this.store,
    this.onChanged,
  });

  final WorkoutRepository local;
  final WorkoutRepository remote;
  final SyncStateStore store;

  /// Gọi khi một lần đồng bộ làm đổi danh sách trên máy (để làm mới màn hình).
  final void Function()? onChanged;

  Future<void>? _running;
  var _again = false;
  Future<SyncState>? _state;

  /// Một bản [SyncState] dùng chung trong bộ nhớ, để ghi và đồng bộ chạy xen kẽ không ghi đè nhau.
  Future<SyncState> _load() => _state ??= store.load();

  @override
  Future<List<Workout>> list() => local.list();

  @override
  Future<Workout?> get(String id) async {
    final w = await local.get(id);
    if (w != null) return w;
    try {
      final r = await remote.get(id);
      if (r == null) return null;
      await local.save(r);
      final s = await _load();
      s.synced.add(id);
      await store.save(s);
      return r;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Workout workout) async {
    await local.save(workout);
    final s = await _load();
    s.pending[workout.id] = 'put';
    await store.save(s);
    unawaited(sync());
  }

  @override
  Future<void> delete(String id) async {
    await local.delete(id);
    final s = await _load();
    s.pending[id] = 'delete';
    await store.save(s);
    unawaited(sync());
  }

  /// Đồng bộ một lượt; gọi chồng thì dùng chung lượt đang chạy. Không bao giờ ném lỗi: mất mạng
  /// hay máy chủ lỗi thì việc còn lại để dành cho lần sau.
  Future<void> sync() {
    final running = _running;
    if (running != null) {
      _again =
          true; // có việc mới trong lúc đang chạy: chạy thêm một lượt sau đó
      return running;
    }
    return _running = _loop();
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _sync();
      } while (_again);
    } finally {
      _running = null;
    }
  }

  Future<void> _sync() async {
    var changed = false;
    try {
      final s = await _load();

      // 1) Đẩy việc đang chờ
      for (final e in s.pending.entries.toList()) {
        try {
          if (e.value == 'delete') {
            await remote.delete(e.key);
            s.synced.remove(e.key);
          } else {
            final w = await local.get(e.key);
            if (w != null) await remote.save(w);
            if (w != null) s.synced.add(e.key);
          }
          s.pending.remove(e.key);
          await store.save(s);
        } on Object catch (err) {
          if (_retryable(err)) return; // để lần sau
          s.pending.remove(
            e.key,
          ); // máy chủ từ chối hẳn (ví dụ 422): thử lại cũng vô ích
          await store.save(s);
        }
      }

      // 2) Kéo về những gì còn thiếu, dọn những gì đã xóa ở máy khác
      final remoteList = await remote.list();
      final remoteIds = {for (final w in remoteList) w.id};
      final localList = await local.list();
      final localIds = {for (final w in localList) w.id};

      for (final r in remoteList) {
        if (localIds.contains(r.id) || s.pending[r.id] == 'delete') continue;
        final full = await remote.get(r.id);
        if (full == null) continue;
        await local.save(full);
        s.synced.add(r.id);
        changed = true;
      }
      for (final l in localList) {
        if (remoteIds.contains(l.id) || s.pending.containsKey(l.id)) continue;
        if (s.synced.contains(l.id)) {
          await local.delete(l.id); // đã bị xóa ở máy khác
          s.synced.remove(l.id);
          changed = true;
        } else {
          await remote.save(
            l,
          ); // chưa từng lên máy chủ (ví dụ ghi lúc chưa đăng nhập)
          s.synced.add(l.id);
        }
      }
      await store.save(s);
    } on Object {
      // Mất mạng, hết phiên, máy chủ lỗi...: không ảnh hưởng dữ liệu trên máy
    } finally {
      if (changed) onChanged?.call();
    }
  }

  /// Lỗi tạm thời (mạng, máy chủ, hết hạn phiên) thì thử lại sau; lỗi 4xx khác là bỏ.
  static bool _retryable(Object e) {
    if (e is! DioException) return true;
    final code = e.response?.statusCode;
    if (code == null) return true;
    return code >= 500 || code == 401 || code == 408 || code == 429;
  }
}

/// Đồng bộ buổi tập của người dùng đang đăng nhập. Mỗi tài khoản có thư mục riêng (`u<id>`) nên
/// buổi tập của người này không lên nhầm tài khoản người kia khi đổi tài khoản trên cùng máy.
final Provider<SyncedWorkoutRepository?> syncedWorkoutRepositoryProvider =
    Provider<SyncedWorkoutRepository?>((ref) {
      final userId = ref.watch(authProvider.select((a) => a.value?.id));
      if (userId == null) return null;
      Future<Directory> base() async {
        final d = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/u$userId',
        );
        if (!d.existsSync()) await d.create(recursive: true);
        return d;
      }

      return SyncedWorkoutRepository(
        local: LocalWorkoutRepository(baseDir: base),
        remote: ApiWorkoutRepository(ref.watch(dioProvider)),
        store: FileSyncStateStore(
          () async => File('${(await base()).path}/workout_sync.json'),
        ),
        onChanged: () => ref.invalidate(workoutsProvider),
      );
    });

/// Đồng bộ một lượt khi mở app hoặc đổi tài khoản.
final workoutSyncProvider = FutureProvider<void>((ref) async {
  await ref.watch(syncedWorkoutRepositoryProvider)?.sync();
});
