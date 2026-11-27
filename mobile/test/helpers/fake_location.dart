import 'dart:async';

import 'package:healthtrack/features/workout/active_workout_store.dart';
import 'package:healthtrack/features/workout/location_source.dart';
import 'package:healthtrack/features/workout/workout.dart';
import 'package:route_tracker/route_tracker.dart';

/// Nguồn vị trí giả: test tự đẩy vị trí vào [emit].
class FakeLocationSource implements LocationSource {
  FakeLocationSource({
    this.perm = LocationPermission.always,
    this.available = true,
  });

  LocationPermission perm;
  bool available;
  bool started = false;
  bool keepAwake = false;
  int openedSettings = 0;
  final _ctrl = StreamController<RawFix>.broadcast(sync: true);

  void emit(RawFix f) => _ctrl.add(f);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<LocationPermission> permission() async => perm;

  @override
  Future<LocationPermission> requestPermission() async {
    if (perm == LocationPermission.notDetermined) {
      perm = LocationPermission.whenInUse;
    }
    return perm;
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  Stream<RawFix> fixes() => _ctrl.stream;

  @override
  Future<RawFix?> lastKnown() async => null;

  @override
  Future<void> setKeepAwake(bool on) async => keepAwake = on;

  @override
  Future<void> openSettings() async => openedSettings++;
}

class MemoryActiveWorkoutStore implements ActiveWorkoutStore {
  Workout? draft;
  int saves = 0;

  @override
  Future<void> save(Workout d) async {
    draft = d;
    saves++;
  }

  @override
  Future<Workout?> load() async => draft;

  @override
  Future<void> clear() async => draft = null;
}
