import Foundation

enum AffirmationCategory: String, CaseIterable, Identifiable {
  case confidence
  case focus
  case calm
  case growth
  case relationships

  var id: String { rawValue }

  var title: String {
    switch self {
    case .confidence:
      "Confidence"
    case .focus:
      "Focus"
    case .calm:
      "Calm"
    case .growth:
      "Growth"
    case .relationships:
      "Relationships"
    }
  }

  var shortTitle: String {
    switch self {
    case .confidence:
      "Self"
    case .focus:
      "Focus"
    case .calm:
      "Calm"
    case .growth:
      "Growth"
    case .relationships:
      "Care"
    }
  }
}

enum MoodKind: String, CaseIterable, Identifiable {
  case radiant = "😄"
  case steady = "🙂"
  case neutral = "😐"
  case low = "😔"
  case stressed = "😤"
  case tired = "😴"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .radiant:
      "Radiant"
    case .steady:
      "Steady"
    case .neutral:
      "Neutral"
    case .low:
      "Low"
    case .stressed:
      "Stressed"
    case .tired:
      "Tired"
    }
  }

  var supportText: String {
    switch self {
    case .radiant:
      "Feeling bright and open."
    case .steady:
      "Grounded and doing okay."
    case .neutral:
      "A balanced, ordinary day."
    case .low:
      "A softer day that needs care."
    case .stressed:
      "A tense day that needs space."
    case .tired:
      "Energy is low today."
    }
  }
}

enum AppLaunchOptions {
  static var screenshotMode: Bool {
    ProcessInfo.processInfo.environment["DAILYBETTER_SCREENSHOT_MODE"] == "1"
  }
}
