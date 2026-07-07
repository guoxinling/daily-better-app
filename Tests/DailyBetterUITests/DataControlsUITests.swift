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
}
