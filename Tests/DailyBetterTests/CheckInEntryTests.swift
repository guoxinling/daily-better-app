import XCTest
@testable import DailyBetter

final class CheckInEntryTests: XCTestCase {
  func testAllMoodsHaveApprovedStableLabelsAndEmoji() {
    XCTAssertEqual(CheckInMood.allCases.map(\.rawValue), [
      "bright", "calm", "okay", "anxious", "low", "overwhelmed"
    ])
    XCTAssertEqual(CheckInMood.allCases.map(\.title), [
      "Bright", "Calm", "Okay", "Anxious", "Low", "Overwhelmed"
    ])
    XCTAssertEqual(CheckInMood.allCases.map(\.emoji), ["😊", "🙂", "😐", "😰", "😔", "😣"])
  }

  func testEntryExposesPersistedEnumValues() {
    let entry = CheckInEntry(
      mood: .anxious,
      noteText: "The meeting kept going in circles.",
      reflectionSource: .ai,
      reflectionStatus: .completed,
      helpfulness: .better
    )
    XCTAssertEqual(entry.mood, .anxious)
    XCTAssertEqual(entry.reflectionSource, .ai)
    XCTAssertEqual(entry.reflectionStatus, .completed)
    XCTAssertEqual(entry.helpfulness, .better)
  }

  func testInitializerAppliesApprovedPersistenceDefaults() {
    let entry = CheckInEntry(mood: .okay)

    XCTAssertEqual(entry.reflectionSourceKey, "none")
    XCTAssertEqual(entry.reflectionStatusKey, "none")
    XCTAssertEqual(entry.helpfulnessKey, "unanswered")
    XCTAssertFalse(entry.safetyRouteShown)
    XCTAssertNil(entry.legacyMoodEntryID)
    XCTAssertNil(entry.noteText)
    XCTAssertNil(entry.reflectionText)
    XCTAssertNil(entry.suggestedActionText)
  }

  func testUnknownStoredMoodPresentsAsOkayWithoutRewritingRawValue() {
    let entry = CheckInEntry(mood: .anxious)
    entry.moodKey = "future-mood"

    XCTAssertEqual(entry.mood, .okay)
    XCTAssertEqual(entry.moodKey, "future-mood")
  }

  func testComputedNonMoodEnumsFallBackWithoutRewritingInvalidStoredRawValues() {
    let entry = CheckInEntry(mood: .anxious)
    entry.reflectionSourceKey = "remote"
    entry.reflectionStatusKey = "stuck"
    entry.helpfulnessKey = "maybe"

    XCTAssertEqual(entry.reflectionSource, .none)
    XCTAssertEqual(entry.reflectionStatus, .none)
    XCTAssertEqual(entry.helpfulness, .unanswered)

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
