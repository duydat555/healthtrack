import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

final workoutCollageMediaProvider = Provider<WorkoutCollageMedia>(
  (ref) => const WorkoutCollageMedia(),
);

class WorkoutCollageMedia {
  const WorkoutCollageMedia();

  Future<ui.Image?> pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2160,
      maxHeight: 2880,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> savePng(Uint8List bytes, String name) =>
      Gal.putImageBytes(bytes, name: name);

  Future<void> sharePng(Uint8List bytes, String name, ui.Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['$name.png'],
        sharePositionOrigin: origin,
      ),
    );
  }
}
