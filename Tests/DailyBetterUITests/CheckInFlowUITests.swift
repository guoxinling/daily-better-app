import XCTest

final class CheckInFlowUITests: XCTestCase {
  func testAccessibilityXXXLComposerReflectActionRemainsHittable() {
    let app = launchComposer(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    overwhelmedMood.tap()

    let reflectButton = app.buttons["checkIn.reflect"]
    XCTAssertTrue(reflectButton.isHittable)
    reflectButton.tap()

    XCTAssertTrue(app.buttons["timeline.detail.back"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["reflection.title"].exists)
  }

  func testMoodOnlyCheckInRoutesIntoTimelineDetail() {
    let app = launchComposer()

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    XCTAssertTrue(overwhelmedMood.waitForExistence(timeout: 5))
    overwhelmedMood.tap()

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.buttons["timeline.detail.back"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Reflection"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
  }

  func testWrittenCheckInReflectsAndOpensSavedReflection() {
    let app = launchComposer(additionalArguments: ["-stub-remote-reflection-success"])

    let anxiousMood = app.buttons["mood.anxious"]
    XCTAssertTrue(anxiousMood.waitForExistence(timeout: 5))
    anxiousMood.tap()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()
    noteField.typeText("I can't settle down tonight.")

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.buttons["timeline.detail.back"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Reflection"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
    XCTAssertTrue(app.staticTexts["You sound wound up, not broken. Your mind is still carrying the day forward."].exists)
    XCTAssertTrue(app.staticTexts["Set the phone down and take ten slow breaths before deciding what to do next."].exists)
  }

  func testSaveWithoutReflectionRoutesIntoTimelineDetail() {
    let app = launchComposer()

    let brightMood = app.buttons["mood.bright"]
    XCTAssertTrue(brightMood.waitForExistence(timeout: 5))
    brightMood.tap()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()
    noteField.typeText("Today felt quieter than usual.")

    app.buttons["checkIn.save"].tap()

    XCTAssertTrue(app.buttons["timeline.detail.back"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Reflection"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Your note"].exists)
    XCTAssertTrue(app.staticTexts["Today felt quieter than usual."].exists)
  }

  func testTextEntryDoesNotShowCustomDoneButton() {
    let app = launchComposer()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()

    XCTAssertFalse(app.buttons["checkIn.dismissKeyboard"].exists)
  }

  func testLongTextKeepsFixedActionsVisibleAboveKeyboard() {
    let app = launchComposer()
    app.buttons["mood.calm"].tap()
    app.textViews["checkIn.note"].tap()
    app.textViews["checkIn.note"].typeText(String(repeating: "A long thought. ", count: 80))

    XCTAssertTrue(app.buttons["checkIn.save"].isHittable)
    XCTAssertTrue(app.buttons["checkIn.reflect"].isHittable)
    XCTAssertGreaterThan(app.buttons["checkIn.save"].frame.minY, app.keyboards.firstMatch.frame.minY - 120)
    XCTAssertFalse(app.buttons["checkIn.dismissKeyboard"].exists)
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
