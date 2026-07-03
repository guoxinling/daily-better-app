import Foundation
import SwiftData
import XCTest
@testable import DailyBetter

@MainActor
final class CheckInRepositoryTests: XCTestCase {
  func testSaveFailureRollsBackPendingInsert() throws {
    let storeDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let storeURL = storeDirectory.appending(path: "CheckInRepository.store")
    try FileManager.default.createDirectory(
      at: storeDirectory,
      withIntermediateDirectories: true
    )

    let schema = Schema([CheckInEntry.self])
    defer { try? eraseStore(at: storeURL, schema: schema) }
    try createStore(at: storeURL, schema: schema)
    let state = try autoreleasepool {
      try failedSaveState(in: storeURL, schema: schema)
    }

    XCTAssertTrue(state.didThrow)
    XCTAssertFalse(state.hasChanges)
    XCTAssertEqual(try storedEntryCount(in: storeURL, schema: schema), 0)
  }

  func testDeleteAllFailureRollsBackPendingDeletes() throws {
    let storeDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let storeURL = storeDirectory.appending(path: "CheckInRepository.store")
    try FileManager.default.createDirectory(
      at: storeDirectory,
      withIntermediateDirectories: true
    )

    let schema = Schema([CheckInEntry.self])
    defer { try? eraseStore(at: storeURL, schema: schema) }
    try seedEntry(in: storeURL, schema: schema)
    let state = try autoreleasepool {
      try failedDeleteState(in: storeURL, schema: schema)
    }

    XCTAssertTrue(state.didThrow)
    XCTAssertFalse(state.hasChanges)
    XCTAssertEqual(state.entryCount, 1)
    XCTAssertNil(state.noteText)
    XCTAssertEqual(try storedEntryCount(in: storeURL, schema: schema), 1)
  }

  private func createStore(at storeURL: URL, schema: Schema) throws {
    try autoreleasepool {
      let configuration = ModelConfiguration(schema: schema, url: storeURL)
      _ = try ModelContainer(for: schema, configurations: [configuration])
    }
  }

  private func seedEntry(in storeURL: URL, schema: Schema) throws {
    try autoreleasepool {
      let configuration = ModelConfiguration(schema: schema, url: storeURL)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let context = ModelContext(container)
      context.insert(CheckInEntry(mood: .drained))
      try context.save()
    }
  }

  private func failedSaveState(
    in storeURL: URL,
    schema: Schema
  ) throws -> (didThrow: Bool, hasChanges: Bool) {
    let configuration = ModelConfiguration(
      schema: schema,
      url: storeURL,
      allowsSave: false
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let repository = SwiftDataCheckInRepository(context: context)
    var didThrow = false

    do {
      try repository.save(CheckInEntry(mood: .good))
    } catch {
      didThrow = true
    }

    return (didThrow, context.hasChanges)
  }

  private func failedDeleteState(
    in storeURL: URL,
    schema: Schema
  ) throws -> (didThrow: Bool, hasChanges: Bool, entryCount: Int, noteText: String?) {
    let configuration = ModelConfiguration(
      schema: schema,
      url: storeURL,
      allowsSave: false
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let repository = SwiftDataCheckInRepository(context: context)
    let storedEntry = try XCTUnwrap(context.fetch(FetchDescriptor<CheckInEntry>()).first)
    storedEntry.noteText = "Pending local edit"
    var didThrow = false

    do {
      try repository.deleteAll()
    } catch {
      didThrow = true
    }

    return (
      didThrow,
      context.hasChanges,
      try context.fetchCount(FetchDescriptor<CheckInEntry>()),
      try context.fetch(FetchDescriptor<CheckInEntry>()).first?.noteText
    )
  }

  private func storedEntryCount(in storeURL: URL, schema: Schema) throws -> Int {
    try autoreleasepool {
      let configuration = ModelConfiguration(schema: schema, url: storeURL)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let context = ModelContext(container)
      return try context.fetchCount(FetchDescriptor<CheckInEntry>())
    }
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
