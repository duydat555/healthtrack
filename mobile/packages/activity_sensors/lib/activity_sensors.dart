import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Trạng thái quyền đếm bước của máy.
enum ActivityPermission { granted, denied, notDetermined, unavailable }

/// Tổng bước của một ngày (giờ địa phương). [distanceM] chỉ có trên iOS.
@immutable
class DailySteps {
  const DailySteps({required this.day, required this.steps, this.distanceM});

  /// Ngày dạng `yyyy-MM-dd`.
  final String day;
  final int steps;
  final double? distanceM;
}

/// Một khoảng thời gian (ví dụ một giấc ngủ do hệ thống phát hiện).
@immutable
class RestInterval {
  const RestInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is RestInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'RestInterval($start → $end)';
}

/// Bước chân trong một khoảng ngắn, do Apple đo (CMPedometer).
@immutable
class StepWindow {
  const StepWindow({
    required this.start,
    required this.steps,
    this.distanceM,
    this.paceSecPerM,
  });

  final DateTime start;
  final int steps;
  final double? distanceM;

  /// Nhịp trung bình lúc đang di chuyển (giây/mét).
  final double? paceSecPerM;
}

/// Cảm biến chuyển động của máy, không phụ thuộc Apple Health hay Health Connect.
class ActivitySensors {
  const ActivitySensors({MethodChannel? channel, EventChannel? steps})
    : _channel = channel ?? const MethodChannel('healthtrack/activity'),
      _steps = steps ?? const EventChannel('healthtrack/activity/steps');

  final MethodChannel _channel;
  final EventChannel _steps;

  /// Máy có cảm biến đếm bước không (false trên nền tảng không hỗ trợ).
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<ActivityPermission> permission() => _permission('permission');

  /// Hiện hộp thoại xin quyền (nếu chưa hỏi) và trả trạng thái sau khi người dùng trả lời.
  Future<ActivityPermission> requestPermission() =>
      _permission('requestPermission');

  Future<ActivityPermission> _permission(String method) async {
    try {
      final name = await _channel.invokeMethod<String>(method);
      return ActivityPermission.values.firstWhere(
        (p) => p.name == name,
        orElse: () => ActivityPermission.unavailable,
      );
    } on MissingPluginException {
      return ActivityPermission.unavailable;
    }
  }

  /// Tổng bước theo từng ngày trong [from, to]. Ngày không có bước bị bỏ qua.
  Future<List<DailySteps>> dailySteps(DateTime from, DateTime to) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'dailySteps',
      _range(from, to),
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        DailySteps(
          day: m['day']! as String,
          steps: (m['steps']! as num).toInt(),
          distanceM: (m['distanceM'] as num?)?.toDouble(),
        ),
    ];
  }

  /// Bước theo từng khoảng [minutes] phút trong [from, to] (chỉ iOS, do Apple đo, kèm quãng đường
  /// và nhịp di chuyển). Android trả danh sách rỗng.
  Future<List<StepWindow>> stepBuckets(
    DateTime from,
    DateTime to, {
    int minutes = 15,
  }) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'stepBuckets',
      {..._range(from, to), 'minutes': minutes},
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        StepWindow(
          start: DateTime.fromMillisecondsSinceEpoch(
            (m['start']! as num).toInt(),
          ),
          steps: (m['steps']! as num).toInt(),
          distanceM: (m['distanceM'] as num?)?.toDouble(),
          paceSecPerM: (m['paceSecPerM'] as num?)?.toDouble(),
        ),
    ];
  }

  /// Các lúc người dùng có dấu hiệu thức (iOS: máy bắt đầu chuyển động; Android: mở màn hình),
  /// đầu vào cho mô hình ước lượng giấc ngủ.
  Future<List<DateTime>> wakeEvents(DateTime from, DateTime to) async {
    final raw = await _channel.invokeListMethod<num>(
      'wakeEvents',
      _range(from, to),
    );
    return [
      for (final ms in raw ?? const <num>[])
        DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
    ]..sort();
  }

  /// Giấc ngủ do hệ thống phát hiện (Android: Google Sleep API). iOS trả rỗng: giấc ngủ của Apple
  /// nằm trong Apple Health.
  Future<List<RestInterval>> sleepSegments(DateTime from, DateTime to) async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'sleepSegments',
        _range(from, to),
      );
      return [
        for (final m in raw ?? const <Map<Object?, Object?>>[])
          RestInterval(
            DateTime.fromMillisecondsSinceEpoch((m['start']! as num).toInt()),
            DateTime.fromMillisecondsSinceEpoch((m['end']! as num).toInt()),
          ),
      ]..sort((a, b) => a.start.compareTo(b.start));
    } on MissingPluginException {
      return const [];
    }
  }

  /// Android: bật tác vụ nền đọc bộ đếm bước và đăng ký Sleep API. iOS: không cần (Apple tự ghi).
  Future<void> startBackground() async {
    try {
      await _channel.invokeMethod<void>('startBackground');
    } on MissingPluginException {
      // Nền tảng không hỗ trợ
    }
  }

  /// Đã được phép đọc dữ liệu cho mô hình giấc ngủ chưa (Android cần "Quyền truy cập dữ liệu sử dụng";
  /// iOS luôn true vì đi cùng quyền chuyển động).
  Future<bool> restAccess() async {
    try {
      return await _channel.invokeMethod<bool>('restAccess') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Mở màn Cài đặt để người dùng cấp quyền đọc lịch sử màn hình (Android).
  Future<void> openRestAccessSettings() =>
      _channel.invokeMethod<void>('openRestAccessSettings');

  /// Số bước từ đầu ngày hôm nay, cập nhật trực tiếp khi đang đi.
  Stream<int> todaySteps() =>
      _steps.receiveBroadcastStream().map((v) => (v as num).toInt());

  Map<String, int> _range(DateTime from, DateTime to) => {
    'from': from.millisecondsSinceEpoch,
    'to': to.millisecondsSinceEpoch,
  };
}
