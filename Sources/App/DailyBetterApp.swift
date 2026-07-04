import SwiftData
import SwiftUI

@main
struct DailyBetterApp: App {
  private let sharedModelContainer: ModelContainer

  init() {
    do {
      sharedModelContainer = try ModelContainer(
        for: Affirmation.self,
        MoodEntry.self,
        CheckInEntry.self,
        AppPreferences.self
      )
      let bootstrapContext = ModelContext(sharedModelContainer)
      AppBootstrapper.bootstrapIfNeeded(in: bootstrapContext)
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      RootTabView()
    }
    .modelContainer(sharedModelContainer)
  }
}
