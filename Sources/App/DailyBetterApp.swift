import SwiftData
import SwiftUI

@main
struct DailyBetterApp: App {
  var body: some Scene {
    WindowGroup {
      RootTabView()
    }
    .modelContainer(for: [Affirmation.self, MoodEntry.self, CheckInEntry.self, AppPreferences.self])
  }
}
