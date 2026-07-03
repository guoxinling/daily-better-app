import Foundation

struct CheckInDraft: Equatable {
  var mood: CheckInMood?
  var noteText: String

  init(mood: CheckInMood? = nil, noteText: String = "") {
    self.mood = mood
    self.noteText = noteText
  }

  var trimmedNote: String {
    noteText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
