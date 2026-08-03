import Foundation

struct CheckInDraft: Equatable {
  var mood: CheckInMood?
  var noteText: String
  var createdAt: Date
  var attachmentTokens: [String]

  init(
    mood: CheckInMood? = nil,
    noteText: String = "",
    createdAt: Date = .now,
    attachmentTokens: [String] = []
  ) {
    self.mood = mood
    self.noteText = noteText
    self.createdAt = createdAt
    self.attachmentTokens = attachmentTokens
  }

  var trimmedNote: String {
    noteText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalized: CheckInDraft {
    CheckInDraft(
      mood: mood,
      noteText: trimmedNote,
      createdAt: createdAt,
      attachmentTokens: attachmentTokens
    )
  }
}
