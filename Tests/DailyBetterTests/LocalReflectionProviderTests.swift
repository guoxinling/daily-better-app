import XCTest
@testable import DailyBetter

final class LocalReflectionProviderTests: XCTestCase {
  func testReflectingDrainedMoodWithoutNoteReturnsLocalContent() async throws {
    let request = ReflectionRequest(
      mood: .drained,
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
        .frustrated,
        "Something is pushing against what you expected or needed. A pause can keep frustration from choosing the next move.",
        "Relax your jaw and shoulders, then write the outcome you actually need."
      ),
      (
        .drained,
        "Your energy is limited right now. A smaller version of the day still counts.",
        "Reduce the next task until it can be started in two minutes."
      ),
      (
        .good,
        "Something feels good enough to notice. Let this moment be real without turning it into another task.",
        "Name one detail you want to remember from this moment."
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
