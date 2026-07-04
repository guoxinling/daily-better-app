import Foundation

enum TimelineCalendar {
  static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
    let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  static func entries(_ entries: [CheckInEntry], on date: Date, calendar: Calendar = .current) -> [CheckInEntry] {
    entries
      .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
      .sorted { $0.createdAt > $1.createdAt }
  }
}
