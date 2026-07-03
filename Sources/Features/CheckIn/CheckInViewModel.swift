import Foundation
import Observation

@MainActor
@Observable
final class CheckInViewModel {
  var selectedMood: CheckInMood?
  var noteText = ""
  var presentedEntry: CheckInEntry?
  var failure: ReflectionError?
  var isReflecting = false

  private let repository: CheckInRepository
  private let localProvider: any ReflectionProviding
  private let remoteProvider: any ReflectionProviding

  init(
    repository: CheckInRepository,
    localProvider: any ReflectionProviding = LocalReflectionProvider(),
    remoteProvider: any ReflectionProviding
  ) {
    self.repository = repository
    self.localProvider = localProvider
    self.remoteProvider = remoteProvider
  }

  func saveWithoutReflection() {
    guard let selectedMood, !isReflecting else { return }

    failure = nil
    presentedEntry = nil

    let normalizedNote = CheckInDraft(
      mood: selectedMood,
      noteText: noteText
    ).trimmedNote
    let entry = CheckInEntry(
      mood: selectedMood,
      noteText: normalizedNote.isEmpty ? nil : normalizedNote
    )

    do {
      try repository.save(entry)
      resetDraft()
    } catch {
      failure = .unavailable
    }
  }

  func reflect() async {
    guard let selectedMood, !isReflecting else { return }
    let draft = CheckInDraft(mood: selectedMood, noteText: noteText)

    failure = nil
    presentedEntry = nil
    isReflecting = true
    defer { isReflecting = false }

    let normalizedNote = draft.trimmedNote
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
      let entry = CheckInEntry(
        mood: selectedMood,
        noteText: normalizedNote.isEmpty ? nil : normalizedNote,
        reflectionText: result.reflectionText,
        suggestedActionText: result.suggestedActionText,
        reflectionSource: result.source,
        reflectionStatus: .completed
      )
      try repository.save(entry)
      presentedEntry = entry
      if currentDraft == draft {
        resetDraft()
      }
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

  private var currentDraft: CheckInDraft {
    CheckInDraft(mood: selectedMood, noteText: noteText)
  }
}
