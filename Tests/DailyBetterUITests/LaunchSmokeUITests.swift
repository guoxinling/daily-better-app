import XCTest

final class LaunchSmokeUITests: XCTestCase {
  func testAppLaunches() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing"]
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
  }
}
