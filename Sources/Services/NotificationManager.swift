import Foundation
import UserNotifications

struct ReminderConfiguration: Equatable {
  let hour: Int
  let minute: Int
  let title = "Daily Better"
  let body = "Take a moment to check in."

  var dateComponents: DateComponents {
    DateComponents(hour: hour, minute: minute)
  }
}

enum NotificationManager {
  static let reminderIdentifier = "dailybetter.check-in-reminder"
  private static let legacyReminderIdentifier = "dailybetter.reminder"
  private static let managedReminderIdentifiers = [
    reminderIdentifier,
    legacyReminderIdentifier,
  ]

  static func requestAuthorization() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }

  static func schedule(_ configuration: ReminderConfiguration) async throws {
    remove()

    let content = UNMutableNotificationContent()
    content.title = configuration.title
    content.body = configuration.body
    content.sound = .default

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: configuration.dateComponents,
      repeats: true
    )
    let request = UNNotificationRequest(
      identifier: reminderIdentifier,
      content: content,
      trigger: trigger
    )

    try await UNUserNotificationCenter.current().add(request)
  }

  static func remove() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: managedReminderIdentifiers
    )
  }

  static func destination(for identifier: String) -> AppDestination? {
    managedReminderIdentifiers.contains(identifier) ? .newEntry : nil
  }
}
