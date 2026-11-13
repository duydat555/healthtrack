/// Dữ liệu Gamification từ `/gamification/*`.
class GamificationSummary {
  const GamificationSummary({
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.challenge,
    required this.newAchievements,
  });

  factory GamificationSummary.fromJson(Map<String, dynamic> j) =>
      GamificationSummary(
        score: j['score'] as int,
        streak: j['streak'] as int,
        bestStreak: j['best_streak'] as int,
        challenge: WeeklyChallenge.fromJson(
          j['challenge'] as Map<String, dynamic>,
        ),
        newAchievements: [
          for (final c in j['new_achievements'] as List<dynamic>) c as String,
        ],
      );

  /// Health Score hôm nay, 0 đến 100.
  final int score;
  final int streak;
  final int bestStreak;
  final WeeklyChallenge challenge;

  /// Mã huy hiệu vừa đạt trong lần tải này (để hiện chúc mừng).
  final List<String> newAchievements;
}

class WeeklyChallenge {
  const WeeklyChallenge({
    required this.title,
    required this.progress,
    required this.target,
  });

  factory WeeklyChallenge.fromJson(Map<String, dynamic> j) => WeeklyChallenge(
    title: j['title'] as String,
    progress: j['progress'] as int,
    target: j['target'] as int,
  );

  final String title;
  final int progress;
  final int target;
}

class Achievement {
  const Achievement({
    required this.code,
    required this.title,
    required this.description,
    required this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
    code: j['code'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    earnedAt: j['earned_at'] == null
        ? null
        : DateTime.parse(j['earned_at'] as String).toLocal(),
  );

  final String code;
  final String title;
  final String description;
  final DateTime? earnedAt;

  bool get earned => earnedAt != null;
}
