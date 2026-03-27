import Foundation
import SwiftData

enum AppBootstrapper {
  @MainActor
  static func bootstrapIfNeeded(in context: ModelContext) {
    var affirmationDescriptor = FetchDescriptor<Affirmation>()
    affirmationDescriptor.fetchLimit = 1
    let hasAffirmations = (try? context.fetch(affirmationDescriptor).isEmpty) == false

    if !hasAffirmations {
      for (index, seed) in SeedData.affirmations.enumerated() {
        context.insert(
          Affirmation(
            text: seed.text,
            category: seed.category,
            createdAt: Date(timeIntervalSince1970: TimeInterval(index))
          )
        )
      }
    }

    var preferencesDescriptor = FetchDescriptor<AppPreferences>()
    preferencesDescriptor.fetchLimit = 1
    let hasPreferences = (try? context.fetch(preferencesDescriptor).isEmpty) == false

    if !hasPreferences {
      context.insert(AppPreferences())
    }

    if AppLaunchOptions.screenshotMode {
      prepareScreenshotData(in: context)
    }

    try? context.save()
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
