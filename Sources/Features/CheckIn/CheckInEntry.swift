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
    legacyMoodEntryID: UUID? = nil
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
  }

  var mood: CheckInMood {
    get { CheckInMood(rawValue: moodKey) ?? .good }
    set { moodKey = newValue.rawValue }
  }

  var reflectionSource: ReflectionSource {
    get { ReflectionSource(rawValue: reflectionSourceKey) ?? .none }
    set { reflectionSourceKey = newValue.rawValue }
  }

  var reflectionStatus: ReflectionStatus {
    get { ReflectionStatus(rawValue: reflectionStatusKey) ?? .none }
    set { reflectionStatusKey = newValue.rawValue }
  }

  var helpfulness: Helpfulness {
    get { Helpfulness(rawValue: helpfulnessKey) ?? .unanswered }
    set { helpfulnessKey = newValue.rawValue }
  }
}
