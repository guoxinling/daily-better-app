import XCTest

final class CheckInFlowUITests: XCTestCase {
  func testMoodOnlyCheckInShowsLocalReflection() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
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
}
