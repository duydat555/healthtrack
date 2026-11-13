import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dữ liệu đọc từ Apple Health, đã ở dạng JSON khớp `POST /sync/healthkit`.
@immutable
class HealthKitBatch {
  const HealthKitBatch({
    this.steps = const [],
    this.sleep = const [],
    this.weights = const [],
  });

  final List<Map<String, Object?>> steps;
  final List<Map<String, Object?>> sleep;
  final List<Map<String, Object?>> weights;

  bool get isEmpty => steps.isEmpty && sleep.isEmpty && weights.isEmpty;

  Map<String, Object?> toJson() => {
    'steps': steps,
    'sleep': sleep,
    'weights': weights,
  };
}

/// Cầu nối tới HealthKit (chỉ iOS). Trên nền tảng khác `isAvailable` trả về false.
class HealthBridge {
  const HealthBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('healthtrack/health');

  final MethodChannel _channel;

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Hiện hộp thoại xin quyền đọc. Trả về true khi người dùng đã trả lời (không có nghĩa là
  /// đã cho phép: iOS giấu việc từ chối quyền đọc, nên cứ đọc rồi xem có dữ liệu hay không).
  Future<bool> requestAuthorization() async =>
      await _channel.invokeMethod<bool>('requestAuthorization') ?? false;

  Future<List<Map<String, Object?>>> _fetch(
    String type,
    DateTime from,
    DateTime to,
  ) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'fetch',
      {
        'type': type,
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
      },
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        m.map((k, v) => MapEntry(k! as String, v)),
    ];
  }

  /// Đọc bước chân, giấc ngủ và cân nặng trong khoảng [from, to].
  Future<HealthKitBatch> read(DateTime from, DateTime to) async =>
      HealthKitBatch(
        steps: await _fetch('steps', from, to),
        sleep: await _fetch('sleep', from, to),
        weights: await _fetch('weight', from, to),
      );
}
