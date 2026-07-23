import XCTest
@testable import DailyBetter

final class ReminderConfigurationTests: XCTestCase {
  func testReminderUsesNeutralCheckInCopy() {
    let configuration = ReminderConfiguration(hour: 20, minute: 30)

    XCTAssertEqual(configuration.title, "Daily Better")
    XCTAssertEqual(configuration.body, "Take a moment to check in.")
    XCTAssertEqual(configuration.dateComponents.hour, 20)
    XCTAssertEqual(configuration.dateComponents.minute, 30)
  }

  func testReminderTapRoutesToNewEntry() {
    XCTAssertEqual(NotificationManager.destination(for: NotificationManager.reminderIdentifier), .newEntry)
    XCTAssertEqual(NotificationManager.destination(for: "dailybetter.reminder"), .newEntry)
    XCTAssertNil(NotificationManager.destination(for: "unrelated.notification"))
  }
}
