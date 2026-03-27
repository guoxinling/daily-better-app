import Foundation
import SwiftData

@Model
final class MoodEntry {
  var id: UUID
  var date: Date
  var emoji: String
  var label: String
  var createdAt: Date

  init(
    id: UUID = UUID(),
    date: Date,
    mood: MoodKind,
    createdAt: Date = .now
  ) {
    self.id = id
    self.date = Calendar.current.startOfDay(for: date)
    self.emoji = mood.rawValue
    self.label = mood.label
    self.createdAt = createdAt
  }

  var moodKind: MoodKind {
    MoodKind(rawValue: emoji) ?? .neutral
  }
}
