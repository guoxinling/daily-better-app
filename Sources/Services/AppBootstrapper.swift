import Foundation
import SwiftData

enum AppBootstrapper {
  @MainActor
  static func bootstrapIfNeeded(in context: ModelContext) {
    let arguments = Set(ProcessInfo.processInfo.arguments)
    let isUITesting = arguments.contains("-ui-testing")
    let shouldResetStore = isUITesting && arguments.contains("-reset-store")
    let shouldSeedCheckIns = isUITesting && arguments.contains("-seed-check-ins")

    if shouldResetStore {
      deleteAll(CheckInEntry.self, in: context)
      deleteAll(MoodEntry.self, in: context)
      deleteAll(AppPreferences.self, in: context)
      try? context.save()
    }

    if (try? context.fetch(FetchDescriptor<AppPreferences>()).isEmpty) != false {
      context.insert(AppPreferences())
    }

    try? context.save()
    CheckInMigrationService.runIfNeeded(in: context)

    if AppLaunchOptions.screenshotMode {
      prepareScreenshotData(in: context)
    }

    if shouldSeedCheckIns {
      seedCheckInIfNeeded(in: context)
    }

    try? context.save()
  }

  @MainActor
  private static func deleteAll<T: PersistentModel>(_ modelType: T.Type, in context: ModelContext) {
    let models = (try? context.fetch(FetchDescriptor<T>())) ?? []
    for model in models {
      context.delete(model)
    }
  }

  @MainActor
  private static func seedCheckInIfNeeded(in context: ModelContext) {
    guard (try? context.fetch(FetchDescriptor<CheckInEntry>()).isEmpty) != false else {
      return
    }

    let today = Calendar.current.startOfDay(for: .now)
    context.insert(
      CheckInEntry(
        createdAt: today,
        mood: .overwhelmed,
        noteText: "Everything piled up today.",
        reflectionSource: .none
      )
    )
  }

  @MainActor
  private static func prepareScreenshotData(in context: ModelContext) {
    let affirmationDescriptor = FetchDescriptor<Affirmation>(sortBy: [SortDescriptor(\.createdAt)])
    let moodDescriptor = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.date)])
    let preferencesDescriptor = FetchDescriptor<AppPreferences>()

    let affirmations = (try? context.fetch(affirmationDescriptor)) ?? []
    let moodEntries = (try? context.fetch(moodDescriptor)) ?? []
    let preferences = (try? context.fetch(preferencesDescriptor)) ?? []

    for (index, affirmation) in affirmations.enumerated() {
      affirmation.isFavorite = index < 5
    }

    if !affirmations.contains(where: \.isCustom) {
      context.insert(
        Affirmation(
          text: SeedData.screenshotCustomAffirmation,
          category: .growth,
          isFavorite: true,
          isCustom: true,
          createdAt: .now.addingTimeInterval(1000)
        )
      )
    }

    for entry in moodEntries {
      context.delete(entry)
    }

    for seed in SeedData.screenshotMoods {
      let date = Calendar.current.date(byAdding: .day, value: seed.dayOffset, to: .now) ?? .now
      context.insert(MoodEntry(date: date, mood: seed.mood))
    }

    if let preference = preferences.first {
      preference.themeKey = ThemeKey.green.rawValue
      preference.textScaleKey = TextScaleKey.medium.rawValue
      preference.reminderEnabled = false
      preference.reminderHour = 20
      preference.reminderMinute = 30
    }
  }
}
