import XCTest

final class NavigationUITests: XCTestCase {
  func testScreenshotTimelineLaunchStartsOnTimeline() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-check-ins"]
    app.launchEnvironment["DAILYBETTER_SCREEN"] = "timeline"
    app.launch()

    let timelineTab = app.buttons["tab.timeline"]
    let checkInTab = app.buttons["tab.checkIn"]

    XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
    XCTAssertTrue(timelineTab.isSelected)
    XCTAssertFalse(checkInTab.isSelected)
  }

  func testRootHasOnlyCheckInAndTimelineDestinations() {
    let app = launchApp()
    let checkInTab = app.buttons["tab.checkIn"]
    let timelineTab = app.buttons["tab.timeline"]

    XCTAssertTrue(checkInTab.waitForExistence(timeout: 5))
    XCTAssertTrue(timelineTab.exists)
    XCTAssertFalse(app.tabBars.buttons["Library"].exists)
    XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
    XCTAssertTrue(checkInTab.isSelected)
    XCTAssertFalse(timelineTab.isSelected)

    timelineTab.tap()
    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Timeline"].exists)
    XCTAssertTrue(timelineTab.isSelected)
    XCTAssertFalse(checkInTab.isSelected)

    checkInTab.tap()
    XCTAssertTrue(app.navigationBars["Daily Better"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Check In"].exists)
    XCTAssertTrue(checkInTab.isSelected)
    XCTAssertFalse(timelineTab.isSelected)
  }

  private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    return app
  }
}
