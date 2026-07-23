import XCTest

final class CheckInFlowUITests: XCTestCase {
  func testAccessibilityXXXLComposerReflectActionRemainsHittable() {
    let app = launchComposer(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    overwhelmedMood.tap()

    let reflectButton = app.buttons["checkIn.reflect"]
    XCTAssertTrue(reflectButton.isHittable)
    reflectButton.tap()

    XCTAssertTrue(app.buttons["checkIn.savePreviewedReflection"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["checkIn.reflectionPreview"].waitForExistence(timeout: 2))
  }

  func testMoodOnlyCheckInReflectsInComposerThenSavesToTimeline() {
    let app = launchComposer()

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    XCTAssertTrue(overwhelmedMood.waitForExistence(timeout: 5))
    overwhelmedMood.tap()

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.buttons["checkIn.savePreviewedReflection"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["checkIn.reflectionPreview"].waitForExistence(timeout: 2))
    app.buttons["checkIn.savePreviewedReflection"].tap()
    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Only a feeling was recorded."].waitForExistence(timeout: 2))
  }

  func testWrittenCheckInReflectsInComposerAndSavesToTimeline() {
    let app = launchComposer(additionalArguments: ["-stub-remote-reflection-success"])

    let anxiousMood = app.buttons["mood.anxious"]
    XCTAssertTrue(anxiousMood.waitForExistence(timeout: 5))
    anxiousMood.tap()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()
    noteField.typeText("I can't settle down tonight.")

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.buttons["checkIn.savePreviewedReflection"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["checkIn.reflectionPreview"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["You sound wound up, not broken. Your mind is still carrying the day forward."].exists)
    XCTAssertTrue(app.staticTexts["Set the phone down and take ten slow breaths before deciding what to do next."].exists)

    app.buttons["checkIn.savePreviewedReflection"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["I can't settle down tonight."].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Reflection saved"].exists)
  }

  func testSaveWithoutReflectionReturnsToTimeline() {
    let app = launchComposer()

    let brightMood = app.buttons["mood.bright"]
    XCTAssertTrue(brightMood.waitForExistence(timeout: 5))
    brightMood.tap()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()
    noteField.typeText("Today felt quieter than usual.")

    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Today felt quieter than usual."].exists)
  }

  func testTextEntryShowsCompactKeyboardDismissButton() {
    let app = launchComposer()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()

    XCTAssertTrue(app.buttons["checkIn.dismissKeyboard"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["checkIn.dismissKeyboard"].isHittable)
    XCTAssertLessThan(app.buttons["checkIn.dismissKeyboard"].frame.width, 80)
  }

  func testTappingEmptyNoteAreaShowsKeyboard() {
    let app = launchComposer()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))

    noteField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["checkIn.dismissKeyboard"].isHittable)
    XCTAssertLessThan(app.buttons["checkIn.dismissKeyboard"].frame.width, 80)
  }

  func testSaveReturnsToTimelineWithoutOpeningDetail() {
    let app = launchComposer()
    app.buttons["mood.calm"].tap()
    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["entry.back"].exists)
    XCTAssertTrue(app.staticTexts["Only a feeling was recorded."].exists)
  }

  func testEditingNoteClearsStaleReflectionAndUpdatesSameEntry() {
    let app = launchReflectedEntryDetail()
    app.buttons["entry.menu"].tap()
    app.buttons["Edit entry"].tap()

    let note = app.textViews["checkIn.note"]
    XCTAssertTrue(note.waitForExistence(timeout: 2))
    note.tap()
    note.typeText(" Updated")
    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 3))
    let updatedNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Updated")).firstMatch
    XCTAssertTrue(updatedNote.waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["Reflection saved"].exists)
  }

  func testLongTextKeepsFixedActionsVisibleAboveKeyboard() {
    let app = launchComposer()
    app.buttons["mood.calm"].tap()
    app.textViews["checkIn.note"].tap()
    app.textViews["checkIn.note"].typeText(String(repeating: "A long thought. ", count: 80))

    XCTAssertTrue(app.buttons["checkIn.save"].isHittable)
    XCTAssertTrue(app.buttons["checkIn.reflect"].isHittable)
    XCTAssertTrue(app.buttons["checkIn.dismissKeyboard"].isHittable)
    XCTAssertLessThan(app.buttons["checkIn.dismissKeyboard"].frame.width, 80)
  }

  func testClosingChangedDraftRequiresDiscardConfirmation() {
    let app = launchComposer()
    app.buttons["mood.bright"].tap()
    app.buttons["checkIn.close"].tap()

    XCTAssertTrue(app.buttons["Discard entry"].waitForExistence(timeout: 2))
  }

  private func launchComposer(
    contentSizeCategory: String? = nil,
    additionalArguments: [String] = []
  ) -> XCUIApplication {
    let app = makeApp(
      contentSizeCategory: contentSizeCategory,
      additionalArguments: additionalArguments
    )
    app.launch()

    let composeButton = app.buttons["timeline.checkIn"]
    XCTAssertTrue(composeButton.waitForExistence(timeout: 5))
    composeButton.tap()
    XCTAssertTrue(app.textViews["checkIn.note"].waitForExistence(timeout: 5))
    return app
  }

  private func launchReflectedEntryDetail() -> XCUIApplication {
    let app = makeApp(additionalArguments: ["-seed-long-reflection-entry"])
    app.launch()
    app.descendants(matching: .any)["timeline.entry.row"].firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Entry"].waitForExistence(timeout: 5))
    return app
  }

  private func assertSingleFullScreenJournalPage(_ app: XCUIApplication) {
    XCTAssertFalse(app.buttons["tab.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.timeline"].exists)
  }

  private func makeApp(
    contentSizeCategory: String? = nil,
    additionalArguments: [String] = []
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"] + additionalArguments

    if let contentSizeCategory {
      app.launchEnvironment["UIPreferredContentSizeCategoryName"] = contentSizeCategory
    }

    return app
  }
}
