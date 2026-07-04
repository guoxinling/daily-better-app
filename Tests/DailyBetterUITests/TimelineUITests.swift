import XCTest

final class TimelineUITests: XCTestCase {
  func testTimelineShowsWeekAndEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store", "-seed-check-ins"]
    app.launch()

    app.buttons["tab.timeline"].tap()

    XCTAssertTrue(app.otherElements["timeline.week"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Everything piled up today."].exists)
  }

  func testSaveWithoutReflectionAddsTimelineEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    app.buttons["mood.good"].tap()
    app.textViews["checkIn.note"].tap()
    app.textViews["checkIn.note"].typeText("The presentation went well.")
    if app.buttons["checkIn.dismissKeyboard"].exists {
      app.buttons["checkIn.dismissKeyboard"].tap()
    }
    app.buttons["checkIn.saveOnly"].tap()
    app.buttons["tab.timeline"].tap()

    XCTAssertTrue(app.staticTexts["The presentation went well."].waitForExistence(timeout: 3))
  }
}
