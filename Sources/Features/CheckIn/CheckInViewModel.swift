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
    guard let selectedMood else { return }

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
    guard let selectedMood else { return }

    failure = nil
    isReflecting = true
    defer { isReflecting = false }

    let normalizedNote = CheckInDraft(
      mood: selectedMood,
      noteText: noteText
    ).trimmedNote
    let request = ReflectionRequest(
      mood: selectedMood,
      noteText: normalizedNote,
      localeIdentifier: Locale.current.identifier,
      requestID: UUID()
    )

    do {
      let provider = normalizedNote.isEmpty ? localProvider : remoteProvider
      let result = try await provider.reflect(request)
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
      resetDraft()
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
}
