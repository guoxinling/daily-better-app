import Foundation

enum CheckInMood: String, CaseIterable, Codable, Identifiable, Sendable {
  case anxious
  case overwhelmed
  case low
  case frustrated
  case drained
  case good

  var id: String { rawValue }

  var title: String {
    switch self {
    case .anxious:
      "Anxious"
    case .overwhelmed:
      "Overwhelmed"
    case .low:
      "Low"
    case .frustrated:
      "Frustrated"
    case .drained:
      "Drained"
    case .good:
      "Good"
    }
  }

  var emoji: String {
    switch self {
    case .anxious:
      "😰"
    case .overwhelmed:
      "😣"
    case .low:
      "😔"
    case .frustrated:
      "😤"
    case .drained:
      "😴"
    case .good:
      "😊"
    }
  }
}
