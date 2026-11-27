import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'workout.dart';

/// Bản nháp buổi tập đang ghi, lưu định kỳ để không mất khi app bị tắt giữa chừng (hết pin, hệ
/// thống thu hồi bộ nhớ). Lần mở sau, màn ghi hỏi người dùng lưu hay bỏ.
abstract class ActiveWorkoutStore {
  Future<void> save(Workout draft);
  Future<Workout?> load();
  Future<void> clear();
}

class FileActiveWorkoutStore implements ActiveWorkoutStore {
  FileActiveWorkoutStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<File> _file() async =>
      File('${(await _baseDir()).path}/active_workout.json');

  @override
  Future<void> save(Workout draft) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Workout?> load() async {
    final f = await _file();
    if (!f.existsSync()) return null;
    try {
      return Workout.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final f = await _file();
    if (f.existsSync()) await f.delete();
  }
}

final activeWorkoutStoreProvider = Provider<ActiveWorkoutStore>(
  (ref) => FileActiveWorkoutStore(),
);
