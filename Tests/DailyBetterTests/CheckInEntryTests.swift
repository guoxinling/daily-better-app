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

  func testInitializerAppliesApprovedPersistenceDefaults() {
    let entry = CheckInEntry(mood: .good)

    XCTAssertEqual(entry.reflectionSourceKey, "none")
    XCTAssertEqual(entry.reflectionStatusKey, "none")
    XCTAssertEqual(entry.helpfulnessKey, "unanswered")
    XCTAssertFalse(entry.safetyRouteShown)
    XCTAssertNil(entry.legacyMoodEntryID)
    XCTAssertNil(entry.noteText)
    XCTAssertNil(entry.reflectionText)
    XCTAssertNil(entry.suggestedActionText)
  }

  func testComputedEnumsFallBackWithoutRewritingInvalidStoredRawValues() {
    let entry = CheckInEntry(mood: .anxious)
    entry.moodKey = "unknown-mood"
    entry.reflectionSourceKey = "remote"
    entry.reflectionStatusKey = "stuck"
    entry.helpfulnessKey = "maybe"

    XCTAssertEqual(entry.mood, .good)
    XCTAssertEqual(entry.reflectionSource, .none)
    XCTAssertEqual(entry.reflectionStatus, .none)
    XCTAssertEqual(entry.helpfulness, .unanswered)

    XCTAssertEqual(entry.moodKey, "unknown-mood")
    XCTAssertEqual(entry.reflectionSourceKey, "remote")
    XCTAssertEqual(entry.reflectionStatusKey, "stuck")
    XCTAssertEqual(entry.helpfulnessKey, "maybe")
  }

  func testHelpfulnessSetterRoundTripsThroughStoredRawValue() {
    let entry = CheckInEntry(mood: .low)

    entry.helpfulness = .better

    XCTAssertEqual(entry.helpfulnessKey, "better")
    XCTAssertEqual(entry.helpfulness, .better)
  }
}
