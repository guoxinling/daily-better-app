import XCTest

final class NavigationUITests: XCTestCase {
  func testRootHasOnlyCheckInAndTimelineDestinations() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    XCTAssertTrue(app.buttons["tab.checkIn"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["tab.timeline"].exists)
    XCTAssertFalse(app.buttons["tab.library"].exists)
    XCTAssertFalse(app.buttons["tab.settings"].exists)
  }
}
