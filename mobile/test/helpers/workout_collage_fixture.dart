import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:healthtrack/features/workout/workout.dart';

Workout collageFixture([String name = 'sample-run-han-river']) =>
    Workout.fromJson(
      jsonDecode(File('test/fixtures/workouts/$name.json').readAsStringSync())
          as Map<String, Object?>,
    );

ui.Image collageTestPhoto(ui.Color color) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(color, ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(16, 12);
  } finally {
    picture.dispose();
  }
}
