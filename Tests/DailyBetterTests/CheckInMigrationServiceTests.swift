import SwiftData
import XCTest
@testable import DailyBetter

@MainActor
final class CheckInMigrationServiceTests: XCTestCase {
  func testRunIfNeededMigratesLegacyMoodEntriesWithoutDeletingThem() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let legacy = MoodEntry(
      id: UUID(),
      date: Date(timeIntervalSince1970: 1_735_689_600),
      mood: .stressed
    )
    let preferences = AppPreferences(migrationVersion: 0)

    context.insert(legacy)
    context.insert(preferences)
    try context.save()

    try CheckInMigrationService.runIfNeeded(in: context)
    try CheckInMigrationService.runIfNeeded(in: context)

    let checkIns = try context.fetch(FetchDescriptor<CheckInEntry>())
    let storedPreferences = try XCTUnwrap(context.fetch(FetchDescriptor<AppPreferences>()).first)
    let legacyMoodEntries = try context.fetch(FetchDescriptor<MoodEntry>())

    XCTAssertEqual(checkIns.count, 1)
    XCTAssertEqual(checkIns.first?.mood, .anxious)
    XCTAssertEqual(checkIns.first?.legacyMoodEntryID, legacy.id)
    XCTAssertEqual(storedPreferences.migrationVersion, 2)
    XCTAssertEqual(legacyMoodEntries.count, 1)
    XCTAssertEqual(legacyMoodEntries.first?.id, legacy.id)
  }

  func testRunIfNeededMapsEveryLegacyMoodKindToExpectedCheckInMood() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let cases: [(MoodKind, CheckInMood)] = [
      (.radiant, .bright),
      (.steady, .calm),
      (.neutral, .okay),
      (.low, .low),
      (.stressed, .anxious),
      (.tired, .low),
    ]

    for (offset, testCase) in cases.enumerated() {
      let legacy = MoodEntry(
        id: UUID(),
        date: Date(timeIntervalSince1970: TimeInterval(1_735_689_600 + offset * 86_400)),
        mood: testCase.0
      )
      context.insert(legacy)
    }
    try context.save()

    try CheckInMigrationService.runIfNeeded(in: context)

    let checkIns = try context.fetch(FetchDescriptor<CheckInEntry>())
    let moodsByLegacyID = Dictionary(
      uniqueKeysWithValues: checkIns.compactMap { entry in
        entry.legacyMoodEntryID.map { ($0, entry.mood) }
      }
    )

    XCTAssertEqual(checkIns.count, cases.count)
    for (legacyMood, expectedMood) in cases {
      let legacy = try XCTUnwrap(
        context.fetch(FetchDescriptor<MoodEntry>()).first(where: { $0.moodKind == legacyMood })
      )
      XCTAssertEqual(moodsByLegacyID[legacy.id], expectedMood)
    }
  }

  func testCheckInEntryPreservesInvalidRawKeysAfterSaveAndRefetch() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let entry = CheckInEntry(
      mood: .okay,
      reflectionSource: .ai,
      reflectionStatus: .completed,
      helpfulness: .better
    )

    entry.moodKey = "mystery"
    entry.reflectionSourceKey = "remote"
    entry.reflectionStatusKey = "stuck"
    entry.helpfulnessKey = "maybe"

    context.insert(entry)
    try context.save()

    let refetchContext = ModelContext(container)
    let stored = try XCTUnwrap(refetchContext.fetch(FetchDescriptor<CheckInEntry>()).first)

    XCTAssertEqual(stored.mood, .okay)
    XCTAssertEqual(stored.reflectionSource, .none)
    XCTAssertEqual(stored.reflectionStatus, .none)
    XCTAssertEqual(stored.helpfulness, .unanswered)
    XCTAssertEqual(stored.moodKey, "mystery")
    XCTAssertEqual(stored.reflectionSourceKey, "remote")
    XCTAssertEqual(stored.reflectionStatusKey, "stuck")
    XCTAssertEqual(stored.helpfulnessKey, "maybe")
  }

  func testAppPreferencesPersistsMigrationAndConsentFieldsAfterSaveAndRefetch() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let acceptedAt = Date(timeIntervalSince1970: 1_735_689_600)
    let preferences = AppPreferences()

    preferences.migrationVersion = 7
    preferences.aiConsentVersion = 3
    preferences.aiConsentAcceptedAt = acceptedAt

    context.insert(preferences)
    try context.save()

    let refetchContext = ModelContext(container)
    let stored = try XCTUnwrap(refetchContext.fetch(FetchDescriptor<AppPreferences>()).first)

    XCTAssertEqual(stored.migrationVersion, 7)
    XCTAssertEqual(stored.aiConsentVersion, 3)
    XCTAssertEqual(stored.aiConsentAcceptedAt, acceptedAt)
  }

  func testRunIfNeededCreatesSinglePreferencesRecordWhenMissing() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    context.insert(MoodEntry(date: Date(timeIntervalSince1970: 1_735_689_600), mood: .steady))
    try context.save()

    try CheckInMigrationService.runIfNeeded(in: context)

    let refetchContext = ModelContext(container)
    let storedPreferences = try refetchContext.fetch(FetchDescriptor<AppPreferences>())
    let storedCheckIns = try refetchContext.fetch(FetchDescriptor<CheckInEntry>())

    XCTAssertEqual(storedPreferences.count, 1)
    XCTAssertEqual(storedPreferences.first?.migrationVersion, 2)
    XCTAssertEqual(storedCheckIns.count, 1)
  }

  func testRunIfNeededRewritesAllVersionOneMoodKeysOnlyOnce() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let moodKeys = ["good", "anxious", "overwhelmed", "low", "frustrated", "drained"]
    let preferences = AppPreferences(migrationVersion: 1)

    for moodKey in moodKeys {
      let entry = CheckInEntry(mood: .anxious)
      entry.moodKey = moodKey
      context.insert(entry)
    }
    context.insert(preferences)
    try context.save()

    try CheckInMigrationService.runIfNeeded(in: context)
    try CheckInMigrationService.runIfNeeded(in: context)

    let storedEntries = try context.fetch(FetchDescriptor<CheckInEntry>())
    let storedPreferences = try XCTUnwrap(context.fetch(FetchDescriptor<AppPreferences>()).first)

    XCTAssertEqual(storedEntries.map(\.moodKey).sorted(), [
      "anxious", "bright", "low", "low", "overwhelmed", "overwhelmed"
    ])
    XCTAssertEqual(storedPreferences.migrationVersion, 2)
    XCTAssertEqual(storedEntries.count, 6)
  }

  private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
      Affirmation.self,
      MoodEntry.self,
      CheckInEntry.self,
      AppPreferences.self,
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
