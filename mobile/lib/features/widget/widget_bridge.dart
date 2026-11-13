import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification/models.dart';
import '../health/health_providers.dart';

/// Cầu nối tới widget màn hình chính và Live Activity (Swift, `ios/Runner/WidgetBridge.swift`).
/// Mọi lỗi đều bị nuốt: widget chỉ là phần thêm, không được làm app hỏng (ví dụ trên Android).
class WidgetBridge {
  const WidgetBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('healthtrack/widget');

  final MethodChannel _channel;

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Không phải iOS
    } on PlatformException {
      // Widget không khả dụng (ví dụ người dùng tắt Live Activity)
    }
  }

  Future<void> saveSnapshot(TodaySummary s, GamificationSummary g) => _call(
    'saveSnapshot',
    jsonEncode({
      'score': g.score,
      'waterMl': s.waterMl,
      'waterGoalMl': s.waterGoalMl.round(),
      'sleepMinutes': s.sleepMinutes ?? 0,
      'sleepGoalMinutes': s.sleepGoalMinutes.round(),
      'medsTaken': s.medsTaken,
      'medsTotal': s.medsTotal,
      'streak': g.streak,
    }),
  );

  Future<void> waterActivity(int currentMl, int goalMl) =>
      _call('waterActivity', {'current': currentMl, 'goal': goalMl});

  Future<void> endWaterActivity() => _call('endWaterActivity');
}

final widgetBridgeProvider = Provider<WidgetBridge>(
  (ref) => const WidgetBridge(),
);
