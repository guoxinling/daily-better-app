import XCTest
@testable import DailyBetter

final class CheckInEntryTests: XCTestCase {
  func testAllMoodsHaveStableLabelsAndEmoji() {
    let moods = CheckInMood.allCases

    XCTAssertEqual(moods.map(\.rawValue), [
      "anxious", "overwhelmed", "low", "frustrated", "drained", "good"
    ])
    XCTAssertEqual(moods.map(\.title), [
      "Anxious", "Overwhelmed", "Low", "Frustrated", "Drained", "Good"
    ])
    XCTAssertEqual(moods.map(\.emoji), [
      "😰", "😣", "😔", "😤", "😴", "😊"
    ])
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
