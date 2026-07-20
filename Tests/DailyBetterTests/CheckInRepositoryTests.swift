import Foundation
import SwiftData
import XCTest
@testable import DailyBetter

@MainActor
final class CheckInRepositoryTests: XCTestCase {
  func testSaveFailureDoesNotRollbackCallerChangesOrLeakFailedInsert() throws {
    let (storeURL, schema) = try makeStore()
    defer { try? eraseStore(at: storeURL, schema: schema) }

    let state = try autoreleasepool {
      try failedSaveState(in: storeURL, schema: schema)
    }

    XCTAssertTrue(state.didThrow)
    XCTAssertTrue(state.callerHasChanges)
    XCTAssertEqual(state.pendingMoodEntryCount, 1)
    XCTAssertEqual(try storedCheckInMoods(in: storeURL, schema: schema), [])

    try saveCheckIn(mood: .bright, in: storeURL, schema: schema)

    XCTAssertEqual(try storedCheckInMoods(in: storeURL, schema: schema), [.bright])
  }

  func testDeleteFailureDoesNotRollbackCallerChangesOrLeakFailedDelete() throws {
    let (storeURL, schema) = try makeStore()
    defer { try? eraseStore(at: storeURL, schema: schema) }
    try seedEntryAndPreferences(in: storeURL, schema: schema)

    let state = try autoreleasepool {
      try failedDeleteState(in: storeURL, schema: schema)
    }

    XCTAssertTrue(state.didThrow)
    XCTAssertTrue(state.callerHasChanges)
    XCTAssertEqual(state.pendingMigrationVersion, 7)
    XCTAssertEqual(try storedCheckInMoods(in: storeURL, schema: schema), [.low])
    XCTAssertEqual(try storedMigrationVersion(in: storeURL, schema: schema), 0)

    try saveCheckIn(mood: .bright, in: storeURL, schema: schema)

    XCTAssertEqual(
      try storedCheckInMoods(in: storeURL, schema: schema).map(\.rawValue).sorted(),
      ["bright", "low"]
    )
  }

  private func makeStore() throws -> (URL, Schema) {
    let storeDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let storeURL = storeDirectory.appending(path: "CheckInRepository.store")
    try FileManager.default.createDirectory(
      at: storeDirectory,
      withIntermediateDirectories: true
    )
    let schema = Schema([
      CheckInEntry.self,
      MoodEntry.self,
      AppPreferences.self,
    ])

    try autoreleasepool {
      let configuration = ModelConfiguration(schema: schema, url: storeURL)
      _ = try ModelContainer(for: schema, configurations: [configuration])
    }
    return (storeURL, schema)
  }

  private func seedEntryAndPreferences(in storeURL: URL, schema: Schema) throws {
    try autoreleasepool {
      let context = try makeContext(in: storeURL, schema: schema)
      context.insert(CheckInEntry(mood: .low))
      context.insert(AppPreferences())
      try context.save()
    }
  }

  private func failedSaveState(
    in storeURL: URL,
    schema: Schema
  ) throws -> (didThrow: Bool, callerHasChanges: Bool, pendingMoodEntryCount: Int) {
    let callerContext = try makeContext(in: storeURL, schema: schema, allowsSave: false)
    callerContext.insert(
      MoodEntry(
        date: Date(timeIntervalSince1970: 1_735_689_600),
        mood: .steady
      )
    )
    let repository = SwiftDataCheckInRepository(context: callerContext)
    var didThrow = false

    do {
      try repository.save(CheckInEntry(mood: .bright))
    } catch {
      didThrow = true
    }

    return (
      didThrow,
      callerContext.hasChanges,
      try callerContext.fetchCount(FetchDescriptor<MoodEntry>())
    )
  }

  private func failedDeleteState(
    in storeURL: URL,
    schema: Schema
  ) throws -> (didThrow: Bool, callerHasChanges: Bool, pendingMigrationVersion: Int) {
    let callerContext = try makeContext(in: storeURL, schema: schema, allowsSave: false)
    let preferences = try XCTUnwrap(
      callerContext.fetch(FetchDescriptor<AppPreferences>()).first
    )
    preferences.migrationVersion = 7
    let repository = SwiftDataCheckInRepository(context: callerContext)
    var didThrow = false

    do {
      try repository.deleteAll()
    } catch {
      didThrow = true
    }

    return (didThrow, callerContext.hasChanges, preferences.migrationVersion)
  }

  private func saveCheckIn(mood: CheckInMood, in storeURL: URL, schema: Schema) throws {
    try autoreleasepool {
      let callerContext = try makeContext(in: storeURL, schema: schema)
      let repository = SwiftDataCheckInRepository(context: callerContext)
      try repository.save(CheckInEntry(mood: mood))
    }
  }

  private func storedCheckInMoods(in storeURL: URL, schema: Schema) throws -> [CheckInMood] {
    try autoreleasepool {
      let context = try makeContext(in: storeURL, schema: schema)
      return try context.fetch(FetchDescriptor<CheckInEntry>()).map(\.mood)
    }
  }

  private func storedMigrationVersion(in storeURL: URL, schema: Schema) throws -> Int {
    try autoreleasepool {
      let context = try makeContext(in: storeURL, schema: schema)
      return try XCTUnwrap(context.fetch(FetchDescriptor<AppPreferences>()).first).migrationVersion
    }
  }

  private func makeContext(
    in storeURL: URL,
    schema: Schema,
    allowsSave: Bool = true
  ) throws -> ModelContext {
    let configuration = ModelConfiguration(
      schema: schema,
      url: storeURL,
      allowsSave: allowsSave
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
  }

  private func eraseStore(at storeURL: URL, schema: Schema) throws {
    try autoreleasepool {
      let configuration = ModelConfiguration(schema: schema, url: storeURL)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      if #available(iOS 18, *) {
        try container.erase()
      } else {
        container.deleteAllData()
      }
    }
  }
}
