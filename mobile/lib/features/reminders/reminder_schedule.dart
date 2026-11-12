enum ReminderKind {
  water('water', 'Đến giờ uống nước', 'Đã đến giờ uống nước.'),
  medication('medication', 'Đến giờ uống thuốc', 'Đã đến giờ uống thuốc.'),
  sleep('sleep', 'Đến giờ đi ngủ', 'Đã đến giờ chuẩn bị đi ngủ.');

  const ReminderKind(this.apiValue, this.title, this.body);

  final String apiValue;
  final String title;
  final String body;

  static ReminderKind parse(String value) => ReminderKind.values.firstWhere(
    (kind) => kind.apiValue == value,
    orElse: () =>
        throw ArgumentError.value(value, 'kind', 'Loại nhắc không hợp lệ'),
  );
}

/// Dữ liệu cần để lập lịch, tương ứng với một reminder từ API.
class ReminderSchedule {
  const ReminderSchedule({
    required this.id,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.enabled,
  }) : assert(id > 0),
       assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59);

  final int id;
  final ReminderKind kind;
  final int hour;
  final int minute;
  final bool enabled;

  factory ReminderSchedule.fromJson(Map<String, dynamic> json) {
    return ReminderSchedule.fromApi(
      id: json['id'] as int,
      kind: json['kind'] as String,
      atTime: (json['at_time'] ?? json['atTime']) as String,
      enabled: json['enabled'] as bool,
    );
  }

  factory ReminderSchedule.fromApi({
    required int id,
    required String kind,
    required String atTime,
    required bool enabled,
  }) {
    final parts = atTime.split(':');
    if (parts.length < 2) {
      throw FormatException('Giờ nhắc phải có định dạng HH:MM[:SS]', atTime);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw FormatException('Giờ nhắc không hợp lệ', atTime);
    }
    return ReminderSchedule(
      id: id,
      kind: ReminderKind.parse(kind),
      hour: hour,
      minute: minute,
      enabled: enabled,
    );
  }
}
