import Foundation
import Observation

@MainActor
@Observable
final class CheckInViewModel {
  var selectedMood: CheckInMood?
  var noteText = ""
  var presentedEntry: CheckInEntry?
  var committedEntry: CheckInEntry?
  var failure: ReflectionError?
  var saveFailure = false
  var isReflecting = false
  let mode: EntryComposerMode

  var hasUnsavedChanges: Bool {
    currentDraft != initialDraft
  }

  private let repository: CheckInRepository
  private let localProvider: any ReflectionProviding
  private let remoteProvider: any ReflectionProviding
  private let onEntryCommitted: ((CheckInEntry) -> Void)?
  private var initialDraft: CheckInDraft
  private var pendingSave: PendingSave?

  init(
    repository: CheckInRepository,
    mode: EntryComposerMode = .create(createdAt: .now),
    localProvider: any ReflectionProviding = LocalReflectionProvider(),
    remoteProvider: any ReflectionProviding,
    onEntryCommitted: ((CheckInEntry) -> Void)? = nil
  ) {
    let initialDraft = Self.draft(for: mode)
    self.repository = repository
    self.mode = mode
    self.localProvider = localProvider
    self.remoteProvider = remoteProvider
    self.onEntryCommitted = onEntryCommitted
    self.initialDraft = initialDraft
    self.selectedMood = initialDraft.mood
    self.noteText = initialDraft.noteText
  }

  func saveWithoutReflection() {
    guard let selectedMood, !isReflecting else { return }

    failure = nil
    saveFailure = false
    pendingSave = nil
    presentedEntry = nil
    committedEntry = nil

    let draft = currentDraft
    let normalizedNote = draft.noteText

    persistAndCommit(
      PendingSave(
        mood: selectedMood,
        noteText: normalizedNote.isEmpty ? nil : normalizedNote,
        reflection: nil,
        draft: draft
      )
    )
  }

  func retryFailedSave() {
    guard let pendingSave, !isReflecting else { return }
    saveFailure = false
    persistAndCommit(pendingSave)
  }

  func reflect() async {
    guard let selectedMood, !isReflecting else { return }
    let draft = currentDraft

    failure = nil
    saveFailure = false
    pendingSave = nil
    presentedEntry = nil
    committedEntry = nil
    isReflecting = true
    defer { isReflecting = false }

    let normalizedNote = draft.noteText
    let request = ReflectionRequest(
      mood: selectedMood,
      noteText: normalizedNote,
      localeIdentifier: Locale.current.identifier,
      requestID: UUID()
    )

    do {
      let provider = normalizedNote.isEmpty ? localProvider : remoteProvider
      let result = try await provider.reflect(request)
      try Task.checkCancellation()
      persistAndCommit(
        PendingSave(
          mood: selectedMood,
          noteText: normalizedNote.isEmpty ? nil : normalizedNote,
          reflection: result,
          draft: draft
        )
      )
    } catch is CancellationError {
      return
    } catch let error as ReflectionError {
      failure = error
    } catch {
      failure = .unavailable
    }
  }

  private func resetDraft() {
    selectedMood = nil
    noteText = ""
  }

  private func persist(
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?
  ) throws -> CheckInEntry {
    switch mode {
    case .create(let createdAt):
      let entry = CheckInEntry(createdAt: createdAt, mood: mood, noteText: noteText)
      apply(reflection, to: entry)
      try repository.save(entry)
      return entry
    case .edit(let entry):
      try repository.update(entry, mood: mood, noteText: noteText, reflection: reflection)
      return entry
    }
  }

  private func apply(_ reflection: ReflectionResult?, to entry: CheckInEntry) {
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

  private func persistAndCommit(_ pendingSave: PendingSave) {
    do {
      let entry = try persist(
        mood: pendingSave.mood,
        noteText: pendingSave.noteText,
        reflection: pendingSave.reflection
      )
      self.pendingSave = nil
      saveFailure = false
      commit(entry, ifDraftIsUnchangedSince: pendingSave.draft)
    } catch {
      self.pendingSave = pendingSave
      saveFailure = true
    }
  }

  private func commit(_ entry: CheckInEntry, ifDraftIsUnchangedSince draft: CheckInDraft) {
    committedEntry = entry
    presentedEntry = entry
    onEntryCommitted?(entry)

    guard currentDraft == draft else { return }
    switch mode {
    case .create:
      resetDraft()
      initialDraft = currentDraft
    case .edit:
      initialDraft = draft
    }
  }

  private var currentDraft: CheckInDraft {
    CheckInDraft(
      mood: selectedMood,
      noteText: noteText,
      createdAt: mode.createdAt
    ).normalized
  }

  private static func draft(for mode: EntryComposerMode) -> CheckInDraft {
    switch mode {
    case .create(let createdAt):
      CheckInDraft(createdAt: createdAt)
    case .edit(let entry):
      CheckInDraft(
        mood: entry.mood,
        noteText: entry.noteText ?? "",
        createdAt: entry.createdAt
      ).normalized
    }
  }

  private struct PendingSave {
    let mood: CheckInMood
    let noteText: String?
    let reflection: ReflectionResult?
    let draft: CheckInDraft
  }
}
