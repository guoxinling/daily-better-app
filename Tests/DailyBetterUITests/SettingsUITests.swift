import XCTest

final class SettingsUITests: XCTestCase {
  func testSettingsShowsMinimalSectionsOnly() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    let settingsButton = app.buttons["settings.open"].firstMatch
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    settingsButton.tap()

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Daily reminder"].exists)
    XCTAssertTrue(app.staticTexts["AI & privacy"].exists)
    XCTAssertTrue(app.staticTexts["Your data"].exists)
    XCTAssertTrue(app.staticTexts["Support"].exists)
    XCTAssertFalse(app.staticTexts["Theme"].exists)
    XCTAssertFalse(app.staticTexts["Text size"].exists)
  }

  func testSettingsNavigationNeverShowsLegacyTabs() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()

    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["tab.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.timeline"].exists)

    let settingsButton = app.buttons["settings.open"].firstMatch
    XCTAssertTrue(settingsButton.exists)
    settingsButton.tap()

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["tab.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.timeline"].exists)

    app.navigationBars["Settings"].buttons["Timeline"].tap()
    XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
    XCTAssertFalse(app.buttons["tab.checkIn"].exists)
    XCTAssertFalse(app.buttons["tab.timeline"].exists)
  }
}
