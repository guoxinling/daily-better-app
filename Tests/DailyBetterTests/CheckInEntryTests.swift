import XCTest
@testable import DailyBetter

final class CheckInEntryTests: XCTestCase {
  func testAllMoodsHaveStableLabelsAndEmoji() {
    XCTAssertEqual(CheckInMood.allCases.map(\.rawValue), [
      "anxious", "overwhelmed", "low", "frustrated", "drained", "good"
    ])
    XCTAssertEqual(CheckInMood.overwhelmed.emoji, "😣")
    XCTAssertEqual(CheckInMood.good.title, "Good")
  }

  func testEntryExposesPersistedEnumValues() {
    let entry = CheckInEntry(
      mood: .frustrated,
      noteText: "The meeting kept going in circles.",
      reflectionSource: .ai,
      reflectionStatus: .completed,
      helpfulness: .better
    )
    XCTAssertEqual(entry.mood, .frustrated)
    XCTAssertEqual(entry.reflectionSource, .ai)
    XCTAssertEqual(entry.reflectionStatus, .completed)
    XCTAssertEqual(entry.helpfulness, .better)
  }
}
