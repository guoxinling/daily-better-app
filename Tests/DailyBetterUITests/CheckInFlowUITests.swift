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

  private func makeApp(contentSizeCategory: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]

    if let contentSizeCategory {
      app.launchEnvironment["UIPreferredContentSizeCategoryName"] = contentSizeCategory
    }

    return app
  }
}
