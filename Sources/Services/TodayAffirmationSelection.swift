import Foundation

enum TodayAffirmationSelection {
  static func dayKey(for date: Date = .now) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return "\(year)-\(month)-\(day)"
  }

  static func dayIndex(for date: Date = .now) -> Int {
    let start = Calendar.current.startOfDay(for: date)
    return Int(start.timeIntervalSinceReferenceDate / 86_400)
  }

  static func currentAffirmation(
    from affirmations: [Affirmation],
    offset: Int,
    date: Date = .now
  ) -> Affirmation? {
    let sorted = affirmations.sorted { lhs, rhs in
      if lhs.isCustom == rhs.isCustom {
        return lhs.createdAt < rhs.createdAt
      }
      return !lhs.isCustom && rhs.isCustom
    }
    guard !sorted.isEmpty else { return nil }
    let index = (dayIndex(for: date) + max(offset, 0)) % sorted.count
    return sorted[index]
  }
}
