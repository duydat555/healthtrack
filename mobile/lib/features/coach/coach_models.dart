/// Một tin nhắn trong cuộc trò chuyện với Coach.
class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.logged = const [],
    this.source,
  });

  final bool fromUser;
  final String text;

  /// Nguồn trả lời: `local` (model trên Mac của bạn) hoặc `claude`.
  final String? source;

  /// Các chỉ số Coach vừa ghi hộ trong câu trả lời này (water, weight...).
  final List<String> logged;

  ChatMessage copyWith({String? text, List<String>? logged, String? source}) =>
      ChatMessage(
        fromUser: fromUser,
        text: text ?? this.text,
        logged: logged ?? this.logged,
        source: source ?? this.source,
      );
}

/// Sự kiện từ luồng SSE của `/coach/chat`.
sealed class CoachEvent {
  const CoachEvent();

  static CoachEvent? parse(Map<String, dynamic> j) => switch (j['type']) {
    'meta' => CoachMeta(j['provider'] as String),
    'text' => CoachText(j['text'] as String),
    'tool' => CoachTool(j['name'] as String),
    'logged' => CoachLogged(j['metric'] as String? ?? ''),
    'done' => const CoachDone(),
    'error' => CoachError(j['message'] as String? ?? 'Coach đang bận'),
    _ => null,
  };
}

class CoachMeta extends CoachEvent {
  const CoachMeta(this.provider);
  final String provider;
}

class CoachText extends CoachEvent {
  const CoachText(this.text);
  final String text;
}

class CoachTool extends CoachEvent {
  const CoachTool(this.name);
  final String name;
}

class CoachLogged extends CoachEvent {
  const CoachLogged(this.metric);
  final String metric;
}

class CoachDone extends CoachEvent {
  const CoachDone();
}

class CoachError extends CoachEvent {
  const CoachError(this.message);
  final String message;
}

class WeeklyInsight {
  const WeeklyInsight({required this.content});

  factory WeeklyInsight.fromJson(Map<String, dynamic> j) =>
      WeeklyInsight(content: j['content'] as String);

  final String content;
}

/// Nguồn trả lời đang dùng được trên máy chủ.
class CoachProviders {
  const CoachProviders({required this.claude, required this.local});

  factory CoachProviders.fromJson(Map<String, dynamic> j) =>
      CoachProviders(claude: j['claude'] as bool, local: j['local'] as bool);

  final bool claude;
  final bool local;
}
