import Foundation
import SwiftData

enum CheckInMigrationService {
  static let currentVersion = 2

  private static let version2MoodMap = [
    "good": "bright",
    "anxious": "anxious",
    "overwhelmed": "overwhelmed",
    "low": "low",
    "frustrated": "overwhelmed",
    "drained": "low",
  ]

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
          createdAt: legacy.createdAt,
          mood: mapLegacyMood(legacy.moodKind),
          reflectionSource: .none,
          legacyMoodEntryID: legacy.id
        )
      )
    }

    for entry in existingCheckIns {
      if let migrated = version2MoodMap[entry.moodKey] {
        entry.moodKey = migrated
      }
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
    case .radiant:
      .bright
    case .steady:
      .calm
    case .neutral:
      .okay
    case .low:
      .low
    case .stressed:
      .anxious
    case .tired:
      .low
    }
  }
}
