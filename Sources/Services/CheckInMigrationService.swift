import Foundation
import SwiftData

enum CheckInMigrationService {
  static let currentVersion = 1

  @MainActor
  static func runIfNeeded(in context: ModelContext) throws {
    let preferences = try fetchOrCreatePreferences(in: context)

    guard preferences.migrationVersion < currentVersion else {
      return
    }

    let legacyEntries = try context.fetch(FetchDescriptor<MoodEntry>())
    let existingCheckIns = try context.fetch(FetchDescriptor<CheckInEntry>())
    let migratedLegacyIDs = Set(existingCheckIns.compactMap(\.legacyMoodEntryID))

    for legacy in legacyEntries where !migratedLegacyIDs.contains(legacy.id) {
      context.insert(
        CheckInEntry(
          createdAt: legacy.date,
          mood: mapLegacyMood(legacy.moodKind),
          reflectionSource: .none,
          legacyMoodEntryID: legacy.id
        )
      )
    }

    preferences.migrationVersion = currentVersion
    try context.save()
  }

  @MainActor
  private static func fetchOrCreatePreferences(in context: ModelContext) throws -> AppPreferences {
    var descriptor = FetchDescriptor<AppPreferences>()
    descriptor.fetchLimit = 1

    if let preferences = try context.fetch(descriptor).first {
      return preferences
    }

    let preferences = AppPreferences()
    context.insert(preferences)
    return preferences
  }

  private static func mapLegacyMood(_ mood: MoodKind) -> CheckInMood {
    switch mood {
    case .radiant, .steady, .neutral:
      .good
    case .low:
      .low
    case .stressed:
      .overwhelmed
    case .tired:
      .drained
    }
  }
}
