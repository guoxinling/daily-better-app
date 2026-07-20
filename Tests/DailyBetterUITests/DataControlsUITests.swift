import XCTest

final class DataControlsUITests: XCTestCase {
  func testDeleteAllRequiresConfirmation() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-seed-check-ins"]
    app.launch()

    app.buttons["settings.open"].firstMatch.tap()
    app.buttons["Delete all entries"].tap()

    XCTAssertTrue(app.buttons["Delete all entries"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Cancel"].exists)
  }

  func testDeleteAllRefreshesTimelineAfterReturningFromSettings() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-check-ins"]
    app.launch()

    XCTAssertTrue(app.descendants(matching: .any)["timeline.entry.row"].waitForExistence(timeout: 5))
    app.buttons["settings.open"].firstMatch.tap()
    app.buttons["Delete all entries"].tap()
    app.alerts.buttons["Delete all entries"].tap()
    app.navigationBars["Settings"].buttons["Timeline"].tap()

    XCTAssertFalse(app.descendants(matching: .any)["timeline.entry.row"].exists)
  }
}
