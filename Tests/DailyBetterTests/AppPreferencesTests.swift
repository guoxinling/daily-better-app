import XCTest
@testable import DailyBetter

final class AppPreferencesTests: XCTestCase {
  func testDefaultsUseStableStoredStrings() {
    let preferences = AppPreferences()

    XCTAssertEqual(preferences.themeKey, "green")
    XCTAssertEqual(preferences.textScaleKey, "medium")
  }
}
