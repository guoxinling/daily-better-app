import Foundation

enum CheckInMood: String, CaseIterable, Codable, Identifiable, Sendable {
  case bright, calm, okay, anxious, low, overwhelmed

  var id: String { rawValue }

  init(storedKey: String) {
    self = CheckInMood(rawValue: storedKey) ?? .okay
  }

  var title: String {
    switch self {
    case .bright:
      "Bright"
    case .calm:
      "Calm"
    case .okay:
      "Okay"
    case .anxious:
      "Anxious"
    case .overwhelmed:
      "Overwhelmed"
    case .low:
      "Low"
    }
  }

  var emoji: String {
    switch self {
    case .bright:
      "😊"
    case .calm:
      "🙂"
    case .okay:
      "😐"
    case .anxious:
      "😰"
    case .overwhelmed:
      "😣"
    case .low:
      "😔"
    }
  }
}
