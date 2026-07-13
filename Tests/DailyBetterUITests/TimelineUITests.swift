import XCTest

final class TimelineUITests: XCTestCase {
  private let longReflectionNote = "I am carrying too many threads at once, replaying every unfinished conversation, and trying to stay composed while my mind keeps spinning through the same worries without landing anywhere useful."
  private let savedReflectionText = "Your mind is looking ahead for what might go wrong. You only need to meet the next moment."
  private let savedSuggestedActionText = "Name one thing you can control in the next five minutes."

  func testTimelineShowsWeekAndEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-check-ins"]
    app.launch()

    app.buttons["tab.timeline"].tap()

    XCTAssertTrue(app.otherElements["timeline.week"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Everything piled up today."].exists)
  }

  func testTimelineRowTruncatesLongNotesToSummaryOnly() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-long-reflection-entry"]
    app.launch()

    app.buttons["tab.timeline"].tap()

    let longNotePreview = app.descendants(matching: .staticText)
      .matching(NSPredicate(format: "label CONTAINS %@", "I am carrying too many threads"))
      .firstMatch
    XCTAssertTrue(longNotePreview.waitForExistence(timeout: 2))
    XCTAssertLessThanOrEqual(longNotePreview.frame.height, 88)
    XCTAssertFalse(app.staticTexts[savedReflectionText].exists)
    XCTAssertFalse(app.staticTexts[savedSuggestedActionText].exists)
    XCTAssertTrue(app.staticTexts["Reflection saved"].exists)
  }

  func testEntryDetailShowsFullSavedReflectionAndSuggestedAction() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-long-reflection-entry"]
    app.launch()

    app.buttons["tab.timeline"].tap()
    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()

    XCTAssertTrue(app.navigationBars["Reflection"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["reflection.title"].exists)
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
    let originalNote = app.descendants(matching: .any)["reflection.originalNote"].firstMatch
    XCTAssertTrue(originalNote.exists)
    XCTAssertEqual(originalNote.label, longReflectionNote)
  }

  func testEntryDetailShowsBackActionAndCanReturnToTimeline() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-long-reflection-entry"]
    app.launch()

    app.buttons["tab.timeline"].tap()
    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()

    let backButton = app.buttons["timeline.detail.back"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 2))

    backButton.tap()

    XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["timeline.detail.back"].exists)
  }

  func testSaveWithoutReflectionAddsTimelineEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    app.buttons["mood.good"].tap()
    app.textViews["checkIn.note"].tap()
    app.textViews["checkIn.note"].typeText("The presentation went well.")
    if app.buttons["checkIn.dismissKeyboard"].exists {
      app.buttons["checkIn.dismissKeyboard"].tap()
    }
    app.buttons["checkIn.saveOnly"].tap()
    app.buttons["tab.timeline"].tap()

    XCTAssertTrue(app.staticTexts["The presentation went well."].waitForExistence(timeout: 3))
  }
}
