import XCTest
@testable import DailyBetter

final class TimelineExportServiceTests: XCTestCase {
  func testExportContainsCurrentEntriesAndLegacyCustomWords() {
    let entry = CheckInEntry(
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      mood: .bright,
      noteText: "The presentation went well."
    )
    let legacy = Affirmation(
      text: "I can begin before I feel ready.",
      category: .confidence,
      isCustom: true
    )

    let export = TimelineExportService.render(entries: [entry], legacyAffirmations: [legacy])

    XCTAssertTrue(export.contains("The presentation went well."))
    XCTAssertTrue(export.contains("Legacy custom words"))
    XCTAssertTrue(export.contains("I can begin before I feel ready."))
  }
}
