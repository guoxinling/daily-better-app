import Foundation
import SwiftData

@MainActor
protocol CheckInRepository: AnyObject {
  func save(_ entry: CheckInEntry) throws
  func update(
    _ entry: CheckInEntry,
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?,
    attachments: [EntryAttachment]
  ) throws
  func setHelpfulness(_ helpfulness: Helpfulness, for entry: CheckInEntry) throws
  func delete(_ entry: CheckInEntry) throws
  func deleteAll() throws
}

@MainActor
extension CheckInRepository {
  func update(
    _ entry: CheckInEntry,
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?
  ) throws {
    try update(
      entry,
      mood: mood,
      noteText: noteText,
      reflection: reflection,
      attachments: entry.orderedAttachments
    )
  }
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepository {
  private let context: ModelContext
  private let attachmentFileStore: EntryAttachmentFileDeleting

  init(
    context: ModelContext,
    attachmentFileStore: EntryAttachmentFileDeleting = EntryAttachmentFileStore()
  ) {
    self.context = ModelContext(context.container)
    self.attachmentFileStore = attachmentFileStore
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
    reflection: ReflectionResult?,
    attachments: [EntryAttachment]
  ) throws {
    let storedEntry = try resolve(entry)
    let snapshot = EntrySnapshot(storedEntry)
    let previousFileNames = Set(storedEntry.orderedAttachments.map(\.fileName))
    let replacementAttachments = attachments.map(copy(of:))
    let nextFileNames = Set(replacementAttachments.map(\.fileName))
    apply(
      mood: mood,
      noteText: noteText,
      reflection: reflection,
      attachments: replacementAttachments,
      to: storedEntry
    )

    do {
      try context.save()
      try attachmentFileStore.delete(fileNames: Array(previousFileNames.subtracting(nextFileNames)))
    } catch {
      snapshot.restore(on: storedEntry)
      context.rollback()
      throw error
    }

    snapshotCommittedFields(from: storedEntry, onto: entry)
  }

  func delete(_ entry: CheckInEntry) throws {
    let storedEntry = try resolve(entry)
    let legacyEntry = try resolveLegacyMoodEntry(id: storedEntry.legacyMoodEntryID)
    let attachmentFileNames = storedEntry.orderedAttachments.map(\.fileName)

    do {
      context.delete(storedEntry)
      if let legacyEntry {
        context.delete(legacyEntry)
      }
      try context.save()
      try attachmentFileStore.delete(fileNames: attachmentFileNames)
    } catch {
      context.rollback()
      throw error
    }
  }

  func setHelpfulness(_ helpfulness: Helpfulness, for entry: CheckInEntry) throws {
    let storedEntry = try resolve(entry)
    let previousHelpfulnessKey = storedEntry.helpfulnessKey
    storedEntry.helpfulness = helpfulness

    do {
      try context.save()
    } catch {
      storedEntry.helpfulnessKey = previousHelpfulnessKey
      context.rollback()
      throw error
    }

    entry.helpfulnessKey = storedEntry.helpfulnessKey
  }

  func deleteAll() throws {
    do {
      let entries = try context.fetch(FetchDescriptor<CheckInEntry>())
      let attachmentFileNames = entries.flatMap { $0.orderedAttachments.map(\.fileName) }
      try context.delete(model: CheckInEntry.self)
      try context.delete(model: MoodEntry.self)
      try context.save()
      try attachmentFileStore.delete(fileNames: attachmentFileNames)
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

  private func resolveLegacyMoodEntry(id: UUID?) throws -> MoodEntry? {
    guard let id else { return nil }
    let descriptor = FetchDescriptor<MoodEntry>(
      predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
  }

  private func apply(
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?,
    attachments: [EntryAttachment],
    to entry: CheckInEntry
  ) {
    entry.moodKey = mood.rawValue
    entry.noteText = noteText
    entry.attachments = attachments

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
      legacyMoodEntryID: entry.legacyMoodEntryID,
      attachments: entry.orderedAttachments.map(copy(of:))
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
    entry.attachments = storedEntry.orderedAttachments.map(copy(of:))
  }

  private func copy(of attachment: EntryAttachment) -> EntryAttachment {
    EntryAttachment(
      id: attachment.id,
      fileName: attachment.fileName,
      sortIndex: attachment.sortIndex,
      createdAt: attachment.createdAt,
      width: attachment.width,
      height: attachment.height,
      byteCount: attachment.byteCount
    )
  }

  private struct EntrySnapshot {
    let moodKey: String
    let noteText: String?
    let reflectionText: String?
    let suggestedActionText: String?
    let reflectionSourceKey: String
    let reflectionStatusKey: String
    let helpfulnessKey: String
    let attachments: [EntryAttachment]

    init(_ entry: CheckInEntry) {
      moodKey = entry.moodKey
      noteText = entry.noteText
      reflectionText = entry.reflectionText
      suggestedActionText = entry.suggestedActionText
      reflectionSourceKey = entry.reflectionSourceKey
      reflectionStatusKey = entry.reflectionStatusKey
      helpfulnessKey = entry.helpfulnessKey
      attachments = entry.orderedAttachments.map {
        EntryAttachment(
          id: $0.id,
          fileName: $0.fileName,
          sortIndex: $0.sortIndex,
          createdAt: $0.createdAt,
          width: $0.width,
          height: $0.height,
          byteCount: $0.byteCount
        )
      }
    }

    func restore(on entry: CheckInEntry) {
      entry.moodKey = moodKey
      entry.noteText = noteText
      entry.reflectionText = reflectionText
      entry.suggestedActionText = suggestedActionText
      entry.reflectionSourceKey = reflectionSourceKey
      entry.reflectionStatusKey = reflectionStatusKey
      entry.helpfulnessKey = helpfulnessKey
      entry.attachments = attachments
    }
  }
}

private enum CheckInRepositoryError: Error {
  case entryNotFound
}
