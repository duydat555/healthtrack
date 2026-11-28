import ActivityKit
import Foundation

/// Dữ liệu dùng chung giữa app và widget extension: nhóm App Group và Live Activity uống nước.
enum AppGroup {
  static let id = "group.vn.edu.vku.healthtrack"
  static let snapshotKey = "widget_snapshot"
}

/// Ảnh chụp số liệu hôm nay mà Flutter ghi cho widget đọc.
struct WidgetSnapshot: Codable {
  var score: Int
  var waterMl: Int
  var waterGoalMl: Int
  var sleepMinutes: Int
  var sleepGoalMinutes: Int
  var medsTaken: Int
  var medsTotal: Int
  var streak: Int

  static let placeholder = WidgetSnapshot(
    score: 68, waterMl: 1200, waterGoalMl: 2000, sleepMinutes: 420, sleepGoalMinutes: 480,
    medsTaken: 1, medsTotal: 2, streak: 3)

  static func load() -> WidgetSnapshot? {
    guard let data = UserDefaults(suiteName: AppGroup.id)?.data(forKey: AppGroup.snapshotKey)
    else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  var waterProgress: Double { goalProgress(waterMl, waterGoalMl) }
  var sleepProgress: Double { goalProgress(sleepMinutes, sleepGoalMinutes) }
  var medsProgress: Double { goalProgress(medsTaken, medsTotal) }

  private func goalProgress(_ value: Int, _ goal: Int) -> Double {
    goal > 0 ? min(Double(value) / Double(goal), 1) : 0
  }
}

@available(iOS 16.2, *)
struct WaterActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var currentMl: Int
    var goalMl: Int
  }
}

/// Live Activity buổi tập ngoài trời: thời gian vận động, quãng đường và nhịp trên màn hình khóa
/// và Dynamic Island. Để chung file này vì nó đã nằm trong cả app lẫn widget extension.
@available(iOS 16.2, *)
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// `run`, `walk` hoặc `ride`.
    var sport: String
    /// Thời gian vận động (không tính lúc tạm dừng) tại thời điểm [updatedAt].
    var movingSeconds: Double
    var distanceM: Double
    /// Nhịp hiện tại (giây/km); nil khi chưa đủ dữ liệu.
    var paceSecPerKm: Double?
    var paused: Bool
    var updatedAt: Date
  }
}
