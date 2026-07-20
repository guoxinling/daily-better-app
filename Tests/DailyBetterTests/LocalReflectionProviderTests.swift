import XCTest
@testable import DailyBetter

final class LocalReflectionProviderTests: XCTestCase {
  func testReflectingLowMoodWithoutNoteReturnsLocalContent() async throws {
    let request = ReflectionRequest(
      mood: .low,
      noteText: "",
      localeIdentifier: "en_US",
      requestID: UUID()
    )

    let result = try await LocalReflectionProvider().reflect(request)

    XCTAssertEqual(result.source, .local)
    XCTAssertFalse(result.reflectionText.isEmpty)
    XCTAssertFalse(result.suggestedActionText.isEmpty)
  }

  func testUnavailableRemoteProviderThrowsUnavailable() async {
    let request = ReflectionRequest(
      mood: .anxious,
      noteText: "A written entry",
      localeIdentifier: "en_US",
      requestID: UUID()
    )

    do {
      _ = try await UnavailableRemoteReflectionProvider().reflect(request)
      XCTFail("Expected the remote provider to be unavailable")
    } catch {
      XCTAssertEqual(error as? ReflectionError, .unavailable)
    }
  }

  func testEveryMoodReturnsApprovedLocalCopy() async throws {
    let expectedCopy: [(CheckInMood, String, String)] = [
      (
        .anxious,
        "Your mind is looking ahead for what might go wrong. You only need to meet the next moment.",
        "Name one thing you can control in the next five minutes."
      ),
      (
        .overwhelmed,
        "Several things may be asking for your attention at once. You do not need to solve the whole day now.",
        "Choose the task with the nearest real consequence and give it five minutes."
      ),
      (
        .low,
        "This moment feels heavy. You are allowed to lower the demands you place on yourself.",
        "Do one caring thing for your body: water, food, fresh air, or rest."
      ),
      (
        .bright,
        "Something feels good enough to notice. Let this moment be real without turning it into another task.",
        "Name one detail you want to remember from this moment."
      ),
      (
        .calm,
        "There is some steadiness here. You can let this moment be enough without asking it to become more.",
        "Notice one thing helping you feel grounded and stay with it for one breath."
      ),
      (
        .okay,
        "You may not need to label this moment as good or bad. Being here is enough information for now.",
        "Take one slow breath and name what you need next, if anything."
      ),
    ]

    for (mood, reflectionText, suggestedActionText) in expectedCopy {
      let request = ReflectionRequest(
        mood: mood,
        noteText: "This text must not affect the result.",
        localeIdentifier: "en_US",
        requestID: UUID()
      )

      let result = try await LocalReflectionProvider().reflect(request)

      XCTAssertEqual(result.reflectionText, reflectionText, "Unexpected reflection for \(mood)")
      XCTAssertEqual(result.suggestedActionText, suggestedActionText, "Unexpected action for \(mood)")
      XCTAssertEqual(result.source, .local, "Unexpected source for \(mood)")
    }
  }
}
