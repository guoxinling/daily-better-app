import Foundation
import SwiftData

@Model
final class AppPreferences {
  var id: UUID
  var reminderEnabled: Bool
  var reminderHour: Int
  var reminderMinute: Int
  var themeKey: String
  var textScaleKey: String

  init(
    id: UUID = UUID(),
    reminderEnabled: Bool = false,
    reminderHour: Int = 20,
    reminderMinute: Int = 30,
    themeKey: String = ThemeKey.green.rawValue,
    textScaleKey: String = TextScaleKey.medium.rawValue
  ) {
    self.id = id
    self.reminderEnabled = reminderEnabled
    self.reminderHour = reminderHour
    self.reminderMinute = reminderMinute
    self.themeKey = themeKey
    self.textScaleKey = textScaleKey
  }

  var theme: ThemeKey {
    ThemeKey(rawValue: themeKey) ?? .green
  }

  var textScale: TextScaleKey {
    TextScaleKey(rawValue: textScaleKey) ?? .medium
  }
}
