import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'workout.dart';
import 'workout_sync.dart';

/// Nơi lưu buổi tập. Bản đầu lưu trên máy ([LocalWorkoutRepository]); bản gọi API `/workouts`
/// (task #251) dùng cùng interface này, nên màn hình không cần đổi.
abstract class WorkoutRepository {
  /// Mới nhất trước.
  Future<List<Workout>> list();
  Future<Workout?> get(String id);
  Future<void> save(Workout workout);
  Future<void> delete(String id);
}

/// Mỗi buổi tập là một file JSON trong thư mục `workouts/` của app.
class LocalWorkoutRepository implements WorkoutRepository {
  LocalWorkoutRepository({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final d = Directory('${(await _baseDir()).path}/workouts');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  /// Id chỉ gồm chữ, số, `-`, `_` nên dùng trực tiếp làm tên file được.
  File _file(Directory d, String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Id buổi tập không hợp lệ');
    }
    return File('${d.path}/$id.json');
  }

  @override
  Future<List<Workout>> list() async {
    final d = await _dir();
    final out = <Workout>[];
    for (final f in d.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        out.add(
          Workout.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, Object?>,
          ),
        );
      } on FormatException {
        // Bỏ qua file hỏng thay vì làm hỏng cả danh sách
      }
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }

  @override
  Future<Workout?> get(String id) async {
    final f = _file(await _dir(), id);
    if (!f.existsSync()) return null;
    return Workout.fromJson(
      jsonDecode(await f.readAsString()) as Map<String, Object?>,
    );
  }

  @override
  Future<void> save(Workout workout) async {
    final f = _file(await _dir(), workout.id);
    // Ghi file tạm rồi đổi tên để không để lại file dở dang khi app bị tắt giữa chừng
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(workout.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(String id) async {
    final f = _file(await _dir(), id);
    if (f.existsSync()) await f.delete();
  }
}

/// Kho buổi tập đang dùng: lưu trên máy và đồng bộ với máy chủ khi đã đăng nhập (xem
/// `workout_sync.dart`); chưa đăng nhập thì chỉ lưu trên máy.
final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) =>
      ref.watch(syncedWorkoutRepositoryProvider) ?? LocalWorkoutRepository(),
);

/// Một buổi tập theo id, đọc từ [WorkoutRepository].
final workoutProvider = FutureProvider.autoDispose.family<Workout?, String>(
  (ref, id) => ref.watch(workoutRepositoryProvider).get(id),
);

/// Danh sách buổi tập, mới nhất trước.
final workoutsProvider = FutureProvider.autoDispose<List<Workout>>(
  (ref) => ref.watch(workoutRepositoryProvider).list(),
);
