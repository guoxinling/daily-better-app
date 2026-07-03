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

    CheckInMigrationService.runIfNeeded(in: context)
    CheckInMigrationService.runIfNeeded(in: context)

    let checkIns = try context.fetch(FetchDescriptor<CheckInEntry>())
    let storedPreferences = try XCTUnwrap(context.fetch(FetchDescriptor<AppPreferences>()).first)
    let legacyMoodEntries = try context.fetch(FetchDescriptor<MoodEntry>())

    XCTAssertEqual(checkIns.count, 1)
    XCTAssertEqual(checkIns.first?.mood, .overwhelmed)
    XCTAssertEqual(checkIns.first?.legacyMoodEntryID, legacy.id)
    XCTAssertEqual(storedPreferences.migrationVersion, 1)
    XCTAssertEqual(legacyMoodEntries.count, 1)
    XCTAssertEqual(legacyMoodEntries.first?.id, legacy.id)
  }

  func testRunIfNeededMapsEveryLegacyMoodKindToExpectedCheckInMood() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let cases: [(MoodKind, CheckInMood)] = [
      (.radiant, .good),
      (.steady, .good),
      (.neutral, .good),
      (.low, .low),
      (.stressed, .overwhelmed),
      (.tired, .drained),
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

    CheckInMigrationService.runIfNeeded(in: context)

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
      mood: .good,
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

    XCTAssertEqual(stored.mood, .good)
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
