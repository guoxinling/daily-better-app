import Foundation

enum CheckInMood: String, CaseIterable, Codable, Identifiable {
  case anxious
  case overwhelmed
  case low
  case frustrated
  case drained
  case good

  var id: String { rawValue }

  var title: String {
    rawValue.capitalized
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
