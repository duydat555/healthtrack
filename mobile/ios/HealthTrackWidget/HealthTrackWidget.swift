import ActivityKit
import SwiftUI
import WidgetKit

// Bảng màu "Mực biển" khớp với mobile/lib/core/theme.dart
private extension Color {
  static let ink = Color(red: 0.949, green: 0.969, blue: 0.961)
  static let inkSoft = Color(red: 0.624, green: 0.714, blue: 0.769)
  static let night = Color(red: 0.039, green: 0.102, blue: 0.165)
  static let water = Color(red: 0.220, green: 0.839, blue: 0.788)
  static let sleep = Color(red: 0.627, green: 0.549, blue: 1.0)
  static let meds = Color(red: 1.0, green: 0.435, blue: 0.380)
  static let ember = Color(red: 1.0, green: 0.541, blue: 0.298)
}

// MARK: Dòng thời gian

struct SnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
  let isPlaceholder: Bool
}

struct SnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    completion(
      SnapshotEntry(
        date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder, isPlaceholder: false))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    let entry = SnapshotEntry(
      date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder, isPlaceholder: false)
    // App gọi reloadAllTimelines mỗi khi có số liệu mới; làm mới thêm sau 30 phút phòng khi app đóng.
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
  }
}

// MARK: Vòng hoạt động

struct Ring: View {
  let progress: Double
  let color: Color
  let width: CGFloat

  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.18), lineWidth: width)
      Circle()
        .trim(from: 0, to: max(progress, 0.001))
        .stroke(
          AngularGradient(colors: [color.opacity(0.7), color], center: .center),
          style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
    }
  }
}

struct Rings: View {
  let snapshot: WidgetSnapshot
  var width: CGFloat = 9

  var body: some View {
    ZStack {
      Ring(progress: snapshot.waterProgress, color: .water, width: width)
      Ring(progress: snapshot.sleepProgress, color: .sleep, width: width)
        .padding(width + 3)
      Ring(progress: snapshot.medsProgress, color: .meds, width: width)
        .padding((width + 3) * 2)
    }
  }
}

// MARK: Giao diện widget

struct SmallView: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 6) {
      Rings(snapshot: snapshot, width: 8)
        .frame(width: 92, height: 92)
        .overlay(
          Text("\(snapshot.score)")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.ink))
      Text("Điểm sức khỏe")
        .font(.caption2).foregroundStyle(Color.inkSoft)
    }
  }
}

struct LegendRow: View {
  let label: String
  let value: String
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(label).font(.caption).foregroundStyle(Color.inkSoft)
      Spacer(minLength: 4)
      Text(value).font(.caption.weight(.bold)).foregroundStyle(Color.ink)
    }
  }
}

struct MediumView: View {
  let snapshot: WidgetSnapshot

  private func hours(_ minutes: Int) -> String {
    String(format: "%.1f", Double(minutes) / 60).replacingOccurrences(of: ".", with: ",")
  }

  var body: some View {
    HStack(spacing: 18) {
      Rings(snapshot: snapshot, width: 10)
        .frame(width: 104, height: 104)
        .overlay(
          Text("\(snapshot.score)")
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.ink))
      VStack(alignment: .leading, spacing: 7) {
        LegendRow(
          label: "Nước",
          value: "\(String(format: "%.1f", Double(snapshot.waterMl) / 1000).replacingOccurrences(of: ".", with: ","))/\(snapshot.waterGoalMl / 1000) lít",
          color: .water)
        LegendRow(
          label: "Ngủ", value: "\(hours(snapshot.sleepMinutes))/\(hours(snapshot.sleepGoalMinutes)) giờ",
          color: .sleep)
        LegendRow(label: "Thuốc", value: "\(snapshot.medsTaken)/\(snapshot.medsTotal) liều", color: .meds)
        HStack(spacing: 4) {
          Image(systemName: "flame.fill").foregroundStyle(Color.ember)
          Text(snapshot.streak > 0 ? "\(snapshot.streak) ngày liền" : "Chưa có chuỗi ngày")
            .font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
        }
      }
    }
  }
}

struct LockCircularView: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    Gauge(value: Double(snapshot.score), in: 0...100) {
      Image(systemName: "heart.fill")
    } currentValueLabel: {
      Text("\(snapshot.score)")
    }
    .gaugeStyle(.accessoryCircular)
  }
}

struct HealthTrackEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SnapshotEntry

  var body: some View {
    switch family {
    case .accessoryCircular: LockCircularView(snapshot: entry.snapshot)
    case .systemMedium: MediumView(snapshot: entry.snapshot)
    default: SmallView(snapshot: entry.snapshot)
    }
  }
}

struct HealthTrackWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HealthTrackWidget", provider: SnapshotProvider()) { entry in
      HealthTrackEntryView(entry: entry)
        .containerBackground(Color.night, for: .widget)
    }
    .configurationDisplayName("Hôm nay")
    .description("Vòng nước, giấc ngủ, thuốc và điểm sức khỏe của bạn.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
  }
}

// MARK: Live Activity uống nước

@available(iOS 16.2, *)
struct WaterLockView: View {
  let state: WaterActivityAttributes.ContentState

  private var done: Bool { state.currentMl >= state.goalMl }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: done ? "checkmark.circle.fill" : "drop.fill").foregroundStyle(Color.water)
        Text(done ? "Đủ nước hôm nay" : "Uống nước").font(.headline).foregroundStyle(Color.ink)
        Spacer()
        Text("\(state.currentMl)/\(state.goalMl) ml")
          .font(.subheadline.weight(.semibold)).foregroundStyle(Color.inkSoft)
      }
      ProgressView(value: min(Double(state.currentMl) / Double(max(state.goalMl, 1)), 1))
        .tint(Color.water)
    }
    .padding(16)
    .activityBackgroundTint(Color.night)
  }
}

@available(iOS 16.2, *)
struct WaterLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WaterActivityAttributes.self) { context in
      WaterLockView(state: context.state)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "drop.fill").foregroundStyle(Color.water).font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.currentMl)/\(context.state.goalMl) ml")
            .font(.subheadline.weight(.semibold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          ProgressView(
            value: min(Double(context.state.currentMl) / Double(max(context.state.goalMl, 1)), 1)
          ).tint(Color.water)
        }
      } compactLeading: {
        Image(systemName: "drop.fill").foregroundStyle(Color.water)
      } compactTrailing: {
        Text("\(context.state.currentMl)").font(.caption.weight(.bold))
      } minimal: {
        Image(systemName: "drop.fill").foregroundStyle(Color.water)
      }
    }
  }
}

@main
struct HealthTrackWidgetBundle: WidgetBundle {
  var body: some Widget {
    HealthTrackWidget()
    if #available(iOS 16.2, *) {
      WaterLiveActivity()
    }
  }
}
