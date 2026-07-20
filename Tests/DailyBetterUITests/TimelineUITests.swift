import XCTest

final class TimelineUITests: XCTestCase {
  private let longReflectionNote = "I am carrying too many threads at once, replaying every unfinished conversation, and trying to stay composed while my mind keeps spinning through the same worries without landing anywhere useful."
  private let savedReflectionText = "Your mind is looking ahead for what might go wrong. You only need to meet the next moment."
  private let savedSuggestedActionText = "Name one thing you can control in the next five minutes."

  func testTimelineShowsWeekAndEntry() {
    let app = launchSeededApp()

    XCTAssertTrue(app.otherElements["timeline.week"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Everything piled up today."].exists)
  }

  func testTimelineHasFixedCheckInAction() {
    let app = launchSeededApp()
    let action = app.buttons["timeline.checkIn"]

    XCTAssertTrue(action.waitForExistence(timeout: 5))
    XCTAssertTrue(action.isHittable)
    XCTAssertGreaterThan(action.frame.minY, app.otherElements["timeline.week"].frame.maxY)
  }

  func testTimelineRowTruncatesLongNotesToSummaryOnly() {
    let app = launchLongEntryApp()

    let longNotePreview = app.descendants(matching: .staticText)
      .matching(NSPredicate(format: "label CONTAINS %@", "I am carrying too many threads"))
      .firstMatch
    XCTAssertTrue(longNotePreview.waitForExistence(timeout: 2))
    XCTAssertLessThanOrEqual(longNotePreview.frame.height, 88)
    XCTAssertFalse(app.staticTexts[savedReflectionText].exists)
    XCTAssertFalse(app.staticTexts[savedSuggestedActionText].exists)
    XCTAssertTrue(app.staticTexts["Reflection saved"].exists)
  }

  func testLongTimelineSummaryStaysAtThreeLines() {
    let app = launchLongEntryApp()
    let preview = app.staticTexts["timeline.entry.note.preview"]

    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertLessThanOrEqual(preview.frame.height, 88)
  }

  func testEntryDetailShowsFullSavedReflectionAndSuggestedAction() {
    let app = launchLongEntryApp()
    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()

    XCTAssertTrue(app.navigationBars["Entry"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["reflection.title"].exists)
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
    let originalNote = app.descendants(matching: .any)["entry.note.full"].firstMatch
    XCTAssertTrue(originalNote.exists)
    XCTAssertEqual(originalNote.label, longReflectionNote)
  }

  func testEntryDetailShowsBackActionAndCanReturnToTimeline() {
    let app = launchLongEntryApp()
    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()

    let backButton = app.buttons["entry.back"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 2))

    backButton.tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["entry.back"].exists)
  }

  func testDeletingEntryConfirmsReturnsToTimelineAndRemovesSelectedRow() {
    let app = launchLongEntryApp()
    let selectedRow = app.descendants(matching: .any)["timeline.entry.row"].firstMatch
    XCTAssertTrue(selectedRow.waitForExistence(timeout: 2))
    selectedRow.tap()

    app.buttons["entry.menu"].tap()
    app.buttons["Delete entry"].tap()
    XCTAssertTrue(app.buttons["Delete entry"].waitForExistence(timeout: 2))
    app.buttons["Delete entry"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.descendants(matching: .any)["timeline.entry.row"].exists)
  }

  func testSaveWithoutReflectionAddsTimelineEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    app.buttons["timeline.checkIn"].tap()
    let brightMood = app.buttons["mood.bright"]
    XCTAssertTrue(brightMood.waitForExistence(timeout: 5))
    brightMood.tap()

    let note = app.textViews["checkIn.note"]
    XCTAssertTrue(note.waitForExistence(timeout: 5))
    note.tap()
    note.typeText("The presentation went well.")
    if app.buttons["checkIn.dismissKeyboard"].exists {
      app.buttons["checkIn.dismissKeyboard"].tap()
    }
    app.buttons["checkIn.save"].tap()
    let backButton = app.buttons["entry.back"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 3))
    backButton.tap()

    XCTAssertTrue(app.staticTexts["The presentation went well."].waitForExistence(timeout: 3))
  }

  private func launchSeededApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-check-ins"]
    app.launch()
    return app
  }

  private func launchLongEntryApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-long-reflection-entry"]
    app.launch()
    return app
  }
}
