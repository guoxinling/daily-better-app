import XCTest

final class CheckInFlowUITests: XCTestCase {
  func testAccessibilityXXXLCompactTabsDoNotInterceptReflect() {
    let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
    app.launch()

    let checkInTab = app.buttons["tab.checkIn"]
    let timelineTab = app.buttons["tab.timeline"]
    XCTAssertTrue(checkInTab.waitForExistence(timeout: 5))
    XCTAssertTrue(timelineTab.exists)
    XCTAssertEqual(checkInTab.label, "Check In")
    XCTAssertEqual(timelineTab.label, "Timeline")
    XCTAssertTrue(checkInTab.isSelected)
    XCTAssertFalse(timelineTab.isSelected)

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    overwhelmedMood.tap()

    let reflectButton = app.buttons["checkIn.reflect"]
    XCTAssertTrue(reflectButton.isHittable)
    XCTAssertLessThanOrEqual(reflectButton.frame.maxY, checkInTab.frame.minY)
    reflectButton.tap()

    XCTAssertTrue(app.staticTexts["reflection.title"].waitForExistence(timeout: 5))
  }

  func testMoodOnlyCheckInShowsLocalReflection() {
    let app = makeApp()
    app.launch()

    let overwhelmedMood = app.buttons["mood.overwhelmed"]
    XCTAssertTrue(overwhelmedMood.waitForExistence(timeout: 5))
    overwhelmedMood.tap()

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.staticTexts["reflection.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)

    app.buttons["reflection.done"].tap()
    XCTAssertTrue(app.staticTexts["How are you?"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["reflection.title"].exists)
  }

  func testWrittenCheckInReflectsAndOpensSavedReflection() {
    let app = makeApp(additionalArguments: ["-stub-remote-reflection-success"])
    app.launch()

    let anxiousMood = app.buttons["mood.anxious"]
    XCTAssertTrue(anxiousMood.waitForExistence(timeout: 5))
    anxiousMood.tap()

    let noteField = app.textViews["checkIn.note"]
    XCTAssertTrue(noteField.waitForExistence(timeout: 2))
    noteField.tap()
    noteField.typeText("I can't settle down tonight.")

    app.buttons["checkIn.reflect"].tap()

    XCTAssertTrue(app.staticTexts["reflection.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
    XCTAssertTrue(app.staticTexts["You sound wound up, not broken. Your mind is still carrying the day forward."].exists)
    XCTAssertTrue(app.staticTexts["Set the phone down and take ten slow breaths before deciding what to do next."].exists)
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
