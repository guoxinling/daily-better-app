import XCTest

final class NavigationUITests: XCTestCase {
  func testLaunchStartsOnTimelineWithoutTabs() {
    let app = launchApp()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["timeline.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.timeline"].exists)
  }

  func testCheckInPresentsFullScreenComposerAndCloseReturnsToTimeline() {
    let app = launchApp()
    app.buttons["timeline.checkIn"].tap()

    XCTAssertTrue(app.textViews["checkIn.note"].waitForExistence(timeout: 2))
    app.buttons["checkIn.close"].tap()
    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
  }

  private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    return app
  }
}
