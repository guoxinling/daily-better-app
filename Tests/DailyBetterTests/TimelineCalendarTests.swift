import XCTest
@testable import DailyBetter

final class TimelineCalendarTests: XCTestCase {
  func testWeekContainsSevenDates() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2

    let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30).date!
    let days = TimelineCalendar.week(containing: date, calendar: calendar)

    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(calendar.component(.day, from: days.first!), 29)
    XCTAssertEqual(calendar.component(.day, from: days.last!), 5)
  }

  func testEntriesFilterToSelectedDay() {
    let calendar = Calendar(identifier: .gregorian)
    let selected = calendar.startOfDay(for: .now)
    let entries = [
      CheckInEntry(createdAt: selected.addingTimeInterval(3600), mood: .good),
      CheckInEntry(createdAt: selected.addingTimeInterval(-3600), mood: .low)
    ]

    XCTAssertEqual(TimelineCalendar.entries(entries, on: selected, calendar: calendar).count, 1)
  }
}
