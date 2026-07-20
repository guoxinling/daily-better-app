import Foundation
import SwiftData

@MainActor
protocol CheckInRepository: AnyObject {
  func save(_ entry: CheckInEntry) throws
  func update(
    _ entry: CheckInEntry,
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?
  ) throws
  func delete(_ entry: CheckInEntry) throws
  func deleteAll() throws
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = ModelContext(context.container)
  }

  func save(_ entry: CheckInEntry) throws {
    do {
      context.insert(copy(of: entry))
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  func update(
    _ entry: CheckInEntry,
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?
  ) throws {
    let storedEntry = try resolve(entry)
    let snapshot = EntrySnapshot(storedEntry)
    apply(mood: mood, noteText: noteText, reflection: reflection, to: storedEntry)

    do {
      try context.save()
    } catch {
      snapshot.restore(on: storedEntry)
      context.rollback()
      throw error
    }

    snapshotCommittedFields(from: storedEntry, onto: entry)
  }

  func delete(_ entry: CheckInEntry) throws {
    let storedEntry = try resolve(entry)

    do {
      context.delete(storedEntry)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  func deleteAll() throws {
    do {
      try context.delete(model: CheckInEntry.self)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  private func resolve(_ entry: CheckInEntry) throws -> CheckInEntry {
    let entryID = entry.id
    let descriptor = FetchDescriptor<CheckInEntry>(
      predicate: #Predicate { $0.id == entryID }
    )
    guard let storedEntry = try context.fetch(descriptor).first else {
      throw CheckInRepositoryError.entryNotFound
    }
    return storedEntry
  }

  private func apply(
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?,
    to entry: CheckInEntry
  ) {
    entry.moodKey = mood.rawValue
    entry.noteText = noteText

    if let reflection {
      entry.reflectionText = reflection.reflectionText
      entry.suggestedActionText = reflection.suggestedActionText
      entry.reflectionSourceKey = reflection.source.rawValue
      entry.reflectionStatusKey = ReflectionStatus.completed.rawValue
    } else {
      entry.reflectionText = nil
      entry.suggestedActionText = nil
      entry.reflectionSourceKey = ReflectionSource.none.rawValue
      entry.reflectionStatusKey = ReflectionStatus.none.rawValue
      entry.helpfulnessKey = Helpfulness.unanswered.rawValue
    }
  }

  private func copy(of entry: CheckInEntry) -> CheckInEntry {
    let copy = CheckInEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      mood: entry.mood,
      noteText: entry.noteText,
      reflectionText: entry.reflectionText,
      suggestedActionText: entry.suggestedActionText,
      reflectionSource: entry.reflectionSource,
      reflectionStatus: entry.reflectionStatus,
      helpfulness: entry.helpfulness,
      safetyRouteShown: entry.safetyRouteShown,
      legacyMoodEntryID: entry.legacyMoodEntryID
    )
    copy.moodKey = entry.moodKey
    copy.reflectionSourceKey = entry.reflectionSourceKey
    copy.reflectionStatusKey = entry.reflectionStatusKey
    copy.helpfulnessKey = entry.helpfulnessKey
    return copy
  }

  private func snapshotCommittedFields(from storedEntry: CheckInEntry, onto entry: CheckInEntry) {
    entry.moodKey = storedEntry.moodKey
    entry.noteText = storedEntry.noteText
    entry.reflectionText = storedEntry.reflectionText
    entry.suggestedActionText = storedEntry.suggestedActionText
    entry.reflectionSourceKey = storedEntry.reflectionSourceKey
    entry.reflectionStatusKey = storedEntry.reflectionStatusKey
    entry.helpfulnessKey = storedEntry.helpfulnessKey
  }

  private struct EntrySnapshot {
    let moodKey: String
    let noteText: String?
    let reflectionText: String?
    let suggestedActionText: String?
    let reflectionSourceKey: String
    let reflectionStatusKey: String
    let helpfulnessKey: String

    init(_ entry: CheckInEntry) {
      moodKey = entry.moodKey
      noteText = entry.noteText
      reflectionText = entry.reflectionText
      suggestedActionText = entry.suggestedActionText
      reflectionSourceKey = entry.reflectionSourceKey
      reflectionStatusKey = entry.reflectionStatusKey
      helpfulnessKey = entry.helpfulnessKey
    }

    func restore(on entry: CheckInEntry) {
      entry.moodKey = moodKey
      entry.noteText = noteText
      entry.reflectionText = reflectionText
      entry.suggestedActionText = suggestedActionText
      entry.reflectionSourceKey = reflectionSourceKey
      entry.reflectionStatusKey = reflectionStatusKey
      entry.helpfulnessKey = helpfulnessKey
    }
  }
}

private enum CheckInRepositoryError: Error {
  case entryNotFound
}
