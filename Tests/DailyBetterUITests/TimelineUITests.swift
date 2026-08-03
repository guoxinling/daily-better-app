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

  func testTimelineUsesSingleVisibleTitle() {
    let app = launchSeededApp()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
    XCTAssertLessThanOrEqual(app.staticTexts.matching(identifier: "Timeline").count, 1)
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

  func testTimelineDrawsSingleContinuousRailForEntries() {
    let app = launchSeededApp()

    XCTAssertTrue(app.otherElements["timeline.entry.rail.continuous"].waitForExistence(timeout: 5))
  }

  func testTimelineShowsEmptyPromptOnDaysWithoutEntries() {
    let app = launchSeededApp()
    let nextWeek = app.buttons["timeline.nextWeek"]
    XCTAssertTrue(nextWeek.waitForExistence(timeout: 5))
    nextWeek.tap()

    XCTAssertTrue(app.otherElements["timeline.empty.row"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.otherElements["timeline.empty.marker"].exists)
    XCTAssertTrue(app.staticTexts["How are you feeling?"].exists)
    XCTAssertTrue(app.staticTexts["Take a moment to check in."].exists)
  }

  func testSettingsButtonDoesNotOverlapWeekNavigation() {
    let app = launchSeededApp()
    let settingsButton = app.buttons["settings.open"]
    let nextWeekButton = app.buttons["timeline.nextWeek"]

    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    XCTAssertTrue(nextWeekButton.waitForExistence(timeout: 5))
    XCTAssertFalse(settingsButton.frame.intersects(nextWeekButton.frame))
    XCTAssertLessThan(settingsButton.frame.maxY, nextWeekButton.frame.minY)
  }

  func testTimelineEntryTimeAlignsWithMarker() {
    let app = launchSeededApp()
    let timeLabel = app.staticTexts["timeline.entry.time"].firstMatch
    let marker = app.otherElements["timeline.entry.marker"].firstMatch

    XCTAssertTrue(timeLabel.waitForExistence(timeout: 5))
    XCTAssertTrue(marker.waitForExistence(timeout: 5))
    XCTAssertLessThanOrEqual(abs(timeLabel.frame.midY - marker.frame.midY), 2)
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
    if app.buttons["checkIn.hideKeyboard"].exists {
      app.buttons["checkIn.hideKeyboard"].tap()
    }
    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["The presentation went well."].waitForExistence(timeout: 3))
  }

  func testSavingFromHistoricalWeekReturnsTimelineToToday() {
    let app = launchSeededApp()
    let previousWeek = app.buttons["timeline.previousWeek"]
    XCTAssertTrue(previousWeek.waitForExistence(timeout: 3))
    previousWeek.tap()
    XCTAssertFalse(app.staticTexts["Everything piled up today."].exists)

    app.buttons["timeline.checkIn"].tap()
    let calmMood = app.buttons["mood.calm"]
    XCTAssertTrue(calmMood.waitForExistence(timeout: 5))
    calmMood.tap()
    XCTAssertTrue(calmMood.isSelected)

    let note = app.textViews["checkIn.note"]
    XCTAssertTrue(note.waitForExistence(timeout: 5))
    note.tap()
    note.typeText("Back on today's page.")

    let saveButton = app.buttons["checkIn.save"]
    XCTAssertTrue(saveButton.isEnabled)
    saveButton.tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Back on today's page."].waitForExistence(timeout: 3))
  }

  func testEditingHistoricalEntryKeepsItsDaySelectedAfterSaving() {
    let app = launchHistoricalEntryApp()
    navigateToHistoricalEntry(in: app)

    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()
    app.buttons["entry.menu"].tap()
    app.buttons["Edit entry"].tap()

    let note = app.textViews["checkIn.note"]
    XCTAssertTrue(note.waitForExistence(timeout: 3))
    note.tap()
    note.typeText(" Historical edit")
    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))

    let selectedDate = app.staticTexts["timeline.selectedDate"]
    XCTAssertTrue(selectedDate.waitForExistence(timeout: 3))
    XCTAssertEqual(selectedDate.label, historicalDateTitle)
    let editedNote = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Historical edit")
    ).firstMatch
    XCTAssertTrue(editedNote.exists)
  }

  func testDeletingHistoricalEntryKeepsItsDaySelected() {
    let app = launchHistoricalEntryApp()
    navigateToHistoricalEntry(in: app)

    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()
    app.buttons["entry.menu"].tap()
    app.buttons["Delete entry"].tap()
    XCTAssertTrue(app.buttons["Delete entry"].waitForExistence(timeout: 2))
    app.buttons["Delete entry"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    let selectedDate = app.staticTexts["timeline.selectedDate"]
    XCTAssertTrue(selectedDate.waitForExistence(timeout: 3))
    XCTAssertEqual(selectedDate.label, historicalDateTitle)
    XCTAssertFalse(app.descendants(matching: .any)["timeline.entry.row"].exists)
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

  private func launchHistoricalEntryApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-ui-testing",
      "-reset-store",
      "-seed-long-reflection-entry",
      "-date-seeded-entry-last-week"
    ]
    app.launch()
    return app
  }

  private func navigateToHistoricalEntry(in app: XCUIApplication) {
    let previousWeek = app.buttons["timeline.previousWeek"]
    XCTAssertTrue(previousWeek.waitForExistence(timeout: 3))
    previousWeek.tap()
    XCTAssertTrue(app.descendants(matching: .any)["timeline.entry.row"].firstMatch.waitForExistence(timeout: 3))
  }

  private var historicalDateTitle: String {
    let historicalDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now) ?? .now
    let style = Date.FormatStyle.dateTime
      .weekday(.wide)
      .month(.wide)
      .day()
      .locale(Locale(identifier: "en_US"))
    return historicalDate.formatted(style)
  }
}
