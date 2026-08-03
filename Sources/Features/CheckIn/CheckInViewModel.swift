import Foundation
import Observation

@MainActor
@Observable
final class CheckInViewModel {
  static let noteCharacterLimit = 500
  static let maxAttachmentCount = 5

  var selectedMood: CheckInMood?
  var noteText = ""
  var attachments: [DraftAttachment] = []
  var presentedEntry: CheckInEntry?
  var committedEntry: CheckInEntry?
  var failure: ReflectionError?
  var saveFailure = false
  var isReflecting = false
  let mode: EntryComposerMode

  var hasUnsavedChanges: Bool {
    currentDraft != initialDraft
  }

  var hasPreviewedReflection: Bool {
    pendingSave?.reflection != nil && presentedEntry != nil
  }

  var saveFailureMessage: String {
    if pendingSave?.wasSentForRemoteReflection == true {
      return "Your entry is still here. Your writing may already have been sent for reflection."
    }
    return "Your entry is still here and has not been sent anywhere."
  }

  private let repository: CheckInRepository
  private let localProvider: any ReflectionProviding
  private let remoteProvider: any ReflectionProviding
  private let attachmentFileStore: EntryAttachmentFileStoring
  private let onEntryCommitted: ((CheckInEntry) -> Void)?
  private var initialDraft: CheckInDraft
  private var pendingSave: PendingSave?
  @ObservationIgnored private var reflectionTask: Task<Void, Never>?

  init(
    repository: CheckInRepository,
    mode: EntryComposerMode = .create(createdAt: .now),
    localProvider: any ReflectionProviding = LocalReflectionProvider(),
    remoteProvider: any ReflectionProviding = ReflectionProviderFactory.makeRemoteProvider(),
    attachmentFileStore: EntryAttachmentFileStoring = EntryAttachmentFileStore(),
    onEntryCommitted: ((CheckInEntry) -> Void)? = nil
  ) {
    let initialDraft = Self.draft(for: mode)
    self.repository = repository
    self.mode = mode
    self.localProvider = localProvider
    self.remoteProvider = remoteProvider
    self.attachmentFileStore = attachmentFileStore
    self.onEntryCommitted = onEntryCommitted
    self.initialDraft = initialDraft
    self.selectedMood = initialDraft.mood
    self.noteText = initialDraft.noteText
    self.attachments = Self.draftAttachments(for: mode, fileStore: attachmentFileStore)
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
        draft: draft,
        attachments: attachments
      )
    )
  }

  func updateMood(_ mood: CheckInMood?) {
    selectedMood = mood
    clearPreviewedReflection()
  }

  func updateNoteText(_ text: String) {
    noteText = String(text.prefix(Self.noteCharacterLimit))
    clearPreviewedReflection()
  }

  func addAttachmentData(_ data: Data) throws {
    guard attachments.count < Self.maxAttachmentCount else { return }
    attachments.append(try attachmentFileStore.prepareAttachment(from: data))
    clearPreviewedReflection()
  }

  func removeAttachment(id: DraftAttachment.ID) {
    attachments.removeAll { $0.id == id }
    clearPreviewedReflection()
  }

  func savePreviewedReflection() {
    guard let pendingSave, pendingSave.reflection != nil, !isReflecting else { return }
    saveFailure = false
    persistAndCommit(pendingSave)
  }

  func retryFailedSave() {
    guard let pendingSave, !isReflecting else { return }
    saveFailure = false
    persistAndCommit(pendingSave)
  }

  func startReflection() {
    guard reflectionTask == nil else { return }
    reflectionTask = Task { [weak self] in
      guard let self else { return }
      await reflect()
      reflectionTask = nil
    }
  }

  func cancelReflection() {
    reflectionTask?.cancel()
  }

  func reflect() async {
    guard let selectedMood, !isReflecting else { return }
    let draft = currentDraft
    let visibleNoteText = noteText

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
      guard self.selectedMood == selectedMood, noteText == visibleNoteText else { return }
      let preview = CheckInEntry(
        createdAt: mode.createdAt,
        mood: selectedMood,
        noteText: normalizedNote.isEmpty ? nil : normalizedNote,
        reflectionText: result.reflectionText,
        suggestedActionText: result.suggestedActionText,
        reflectionSource: result.source,
        reflectionStatus: .completed,
        attachments: previewAttachments()
      )
      pendingSave = PendingSave(
        mood: selectedMood,
        noteText: normalizedNote.isEmpty ? nil : normalizedNote,
        reflection: result,
        draft: draft,
        attachments: attachments
      )
      presentedEntry = preview
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
    attachments = []
  }

  private func clearPreviewedReflection() {
    guard !isReflecting else { return }
    presentedEntry = nil
    pendingSave = nil
  }

  private func persist(
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?,
    attachments: [DraftAttachment]
  ) throws -> CheckInEntry {
    let persistedAttachments = try attachments.enumerated().map { offset, attachment in
      try attachmentFileStore.persist(attachment, sortIndex: offset)
    }

    switch mode {
    case .create(let createdAt):
      let entry = CheckInEntry(
        createdAt: createdAt,
        mood: mood,
        noteText: noteText,
        attachments: persistedAttachments
      )
      apply(reflection, to: entry)
      try repository.save(entry)
      return entry
    case .edit(let entry):
      try repository.update(
        entry,
        mood: mood,
        noteText: noteText,
        reflection: reflection,
        attachments: persistedAttachments
      )
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
        reflection: pendingSave.reflection,
        attachments: pendingSave.attachments
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
    presentedEntry = nil
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
      createdAt: mode.createdAt,
      attachmentTokens: attachments.map(\.identityToken)
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
        createdAt: entry.createdAt,
        attachmentTokens: entry.orderedAttachments.map(\.fileName)
      ).normalized
    }
  }

  private static func draftAttachments(
    for mode: EntryComposerMode,
    fileStore: EntryAttachmentFileStoring
  ) -> [DraftAttachment] {
    guard case .edit(let entry) = mode else { return [] }
    return entry.orderedAttachments.compactMap { fileStore.draftAttachment(for: $0) }
  }

  private func previewAttachments() -> [EntryAttachment] {
    attachments.enumerated().map { offset, attachment in
      EntryAttachment(
        fileName: attachment.storedFileName ?? attachment.identityToken,
        sortIndex: offset,
        width: attachment.width,
        height: attachment.height,
        byteCount: attachment.byteCount
      )
    }
  }

  private struct PendingSave {
    let mood: CheckInMood
    let noteText: String?
    let reflection: ReflectionResult?
    let draft: CheckInDraft
    let attachments: [DraftAttachment]

    var wasSentForRemoteReflection: Bool {
      noteText != nil && reflection != nil
    }
  }
}
