import Flutter
import HealthKit
import UIKit

/// Cầu nối HealthKit cho Dart qua kênh `healthtrack/health`.
/// Chỉ đọc: bước chân (tổng theo ngày), giấc ngủ (gộp thành phiên) và cân nặng.
public class HealthBridgePlugin: NSObject, FlutterPlugin {
  private let store = HKHealthStore()
  private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "healthtrack/health", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(HealthBridgePlugin(), channel: channel)
  }

  private var readTypes: Set<HKObjectType> {
    var types = Set<HKObjectType>()
    if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
    if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }
    return types
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(HKHealthStore.isHealthDataAvailable())
    case "requestAuthorization":
      guard HKHealthStore.isHealthDataAvailable() else { return result(false) }
      store.requestAuthorization(toShare: nil, read: readTypes) { ok, error in
        if let error = error {
          result(FlutterError(code: "auth_failed", message: error.localizedDescription, details: nil))
        } else {
          result(ok)
        }
      }
    case "fetch":
      guard let args = call.arguments as? [String: Any],
        let type = args["type"] as? String,
        let fromMs = args["from"] as? Int,
        let toMs = args["to"] as? Int
      else { return result(FlutterError(code: "bad_args", message: "Thiếu type, from hoặc to", details: nil)) }
      let from = Date(timeIntervalSince1970: Double(fromMs) / 1000)
      let to = Date(timeIntervalSince1970: Double(toMs) / 1000)
      switch type {
      case "steps": fetchSteps(from, to, result)
      case "sleep": fetchSleep(from, to, result)
      case "weight": fetchWeight(from, to, result)
      default: result(FlutterError(code: "bad_type", message: "Loại không hỗ trợ: \(type)", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Bước chân

  private func fetchSteps(_ from: Date, _ to: Date, _ result: @escaping FlutterResult) {
    guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return result([]) }
    let cal = Calendar.current
    let anchor = cal.startOfDay(for: from)
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: HKQuery.predicateForSamples(withStart: anchor, end: to, options: .strictStartDate),
      options: .cumulativeSum,
      anchorDate: anchor,
      intervalComponents: DateComponents(day: 1))
    query.initialResultsHandler = { _, collection, error in
      if let error = error {
        return result(FlutterError(code: "query_failed", message: error.localizedDescription, details: nil))
      }
      let fmt = DateFormatter()
      fmt.calendar = cal
      fmt.dateFormat = "yyyy-MM-dd"
      var out: [[String: Any]] = []
      collection?.enumerateStatistics(from: anchor, to: to) { stat, _ in
        let count = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        if count > 0 { out.append(["day": fmt.string(from: stat.startDate), "steps": count]) }
      }
      result(out)
    }
    store.execute(query)
  }

  // MARK: Giấc ngủ

  /// Chỉ tính các giai đoạn đang ngủ (không tính "trên giường" và "thức").
  private func isAsleep(_ value: Int) -> Bool {
    if #available(iOS 16.0, *) {
      switch HKCategoryValueSleepAnalysis(rawValue: value) {
      case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
      default: return false
      }
    }
    return value == HKCategoryValueSleepAnalysis.asleep.rawValue
  }

  private func fetchSleep(_ from: Date, _ to: Date, _ result: @escaping FlutterResult) {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return result([]) }
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(
      sampleType: type,
      predicate: HKQuery.predicateForSamples(withStart: from, end: to, options: []),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [sort]
    ) { [iso] _, samples, error in
      if let error = error {
        return result(FlutterError(code: "query_failed", message: error.localizedDescription, details: nil))
      }
      // Gộp các giai đoạn liền kề (cách nhau tối đa 30 phút) thành một phiên ngủ.
      // external_id lấy từ mẫu đầu tiên của phiên nên ổn định khi đồng bộ lại.
      var sessions: [(id: String, start: Date, end: Date)] = []
      for s in (samples as? [HKCategorySample]) ?? [] where self.isAsleep(s.value) {
        if let last = sessions.last, s.startDate.timeIntervalSince(last.end) <= 30 * 60 {
          sessions[sessions.count - 1].end = max(last.end, s.endDate)
        } else {
          sessions.append((s.uuid.uuidString, s.startDate, s.endDate))
        }
      }
      result(sessions.map {
        ["external_id": $0.id, "start_at": iso.string(from: $0.start), "end_at": iso.string(from: $0.end)]
      })
    }
    store.execute(query)
  }

  // MARK: Cân nặng

  private func fetchWeight(_ from: Date, _ to: Date, _ result: @escaping FlutterResult) {
    guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return result([]) }
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(
      sampleType: type,
      predicate: HKQuery.predicateForSamples(withStart: from, end: to, options: []),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [sort]
    ) { [iso] _, samples, error in
      if let error = error {
        return result(FlutterError(code: "query_failed", message: error.localizedDescription, details: nil))
      }
      result(((samples as? [HKQuantitySample]) ?? []).map {
        [
          "external_id": $0.uuid.uuidString,
          "weight_kg": $0.quantity.doubleValue(for: .gramUnit(with: .kilo)),
          "logged_at": iso.string(from: $0.startDate),
        ]
      })
    }
    store.execute(query)
  }
}
