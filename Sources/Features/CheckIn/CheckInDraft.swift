import Foundation

struct CheckInDraft: Equatable {
  var mood: CheckInMood?
  var noteText: String
  var createdAt: Date

  init(
    mood: CheckInMood? = nil,
    noteText: String = "",
    createdAt: Date = .now
  ) {
    self.mood = mood
    self.noteText = noteText
    self.createdAt = createdAt
  }

  var trimmedNote: String {
    noteText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalized: CheckInDraft {
    CheckInDraft(mood: mood, noteText: trimmedNote, createdAt: createdAt)
  }
}
