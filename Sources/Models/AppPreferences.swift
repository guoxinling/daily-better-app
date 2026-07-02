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
  var migrationVersion: Int = 0
  var aiConsentVersion: Int = 0
  var aiConsentAcceptedAt: Date?

  init(
    id: UUID = UUID(),
    reminderEnabled: Bool = false,
    reminderHour: Int = 20,
    reminderMinute: Int = 30,
    themeKey: String = ThemeKey.green.rawValue,
    textScaleKey: String = TextScaleKey.medium.rawValue,
    migrationVersion: Int = 0,
    aiConsentVersion: Int = 0,
    aiConsentAcceptedAt: Date? = nil
  ) {
    self.id = id
    self.reminderEnabled = reminderEnabled
    self.reminderHour = reminderHour
    self.reminderMinute = reminderMinute
    self.themeKey = themeKey
    self.textScaleKey = textScaleKey
    self.migrationVersion = migrationVersion
    self.aiConsentVersion = aiConsentVersion
    self.aiConsentAcceptedAt = aiConsentAcceptedAt
  }

  var theme: ThemeKey {
    ThemeKey(rawValue: themeKey) ?? .green
  }

  var textScale: TextScaleKey {
    TextScaleKey(rawValue: textScaleKey) ?? .medium
  }
}
