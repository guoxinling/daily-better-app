import Foundation
import SwiftData

@Model
final class CheckInEntry {
  var id: UUID
  var createdAt: Date
  var moodKey: String
  var noteText: String?
  var reflectionText: String?
  var suggestedActionText: String?
  var reflectionSourceKey: String
  var reflectionStatusKey: String
  var helpfulnessKey: String
  var safetyRouteShown: Bool
  var legacyMoodEntryID: UUID?
  @Relationship(deleteRule: .cascade) var attachments: [EntryAttachment]

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    mood: CheckInMood,
    noteText: String? = nil,
    reflectionText: String? = nil,
    suggestedActionText: String? = nil,
    reflectionSource: ReflectionSource = .none,
    reflectionStatus: ReflectionStatus = .none,
    helpfulness: Helpfulness = .unanswered,
    safetyRouteShown: Bool = false,
    legacyMoodEntryID: UUID? = nil,
    attachments: [EntryAttachment] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.moodKey = mood.rawValue
    self.noteText = noteText
    self.reflectionText = reflectionText
    self.suggestedActionText = suggestedActionText
    self.reflectionSourceKey = reflectionSource.rawValue
    self.reflectionStatusKey = reflectionStatus.rawValue
    self.helpfulnessKey = helpfulness.rawValue
    self.safetyRouteShown = safetyRouteShown
    self.legacyMoodEntryID = legacyMoodEntryID
    self.attachments = attachments
  }

  var mood: CheckInMood {
    CheckInMood(storedKey: moodKey)
  }

  var reflectionSource: ReflectionSource {
    ReflectionSource(rawValue: reflectionSourceKey) ?? .none
  }

  var reflectionStatus: ReflectionStatus {
    ReflectionStatus(rawValue: reflectionStatusKey) ?? .none
  }

  var helpfulness: Helpfulness {
    get { Helpfulness(rawValue: helpfulnessKey) ?? .unanswered }
    set { helpfulnessKey = newValue.rawValue }
  }

  var orderedAttachments: [EntryAttachment] {
    attachments.sorted {
      if $0.sortIndex == $1.sortIndex {
        return $0.createdAt < $1.createdAt
      }
      return $0.sortIndex < $1.sortIndex
    }
  }
}
