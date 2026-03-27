import Foundation
import UserNotifications

enum NotificationManager {
  static let reminderIdentifier = "dailybetter.reminder"

  static func requestAuthorization() async -> Bool {
    let center = UNUserNotificationCenter.current()
    return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
  }

  static func removeReminder() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
  }

  static func scheduleReminder(hour: Int, minute: Int) async throws {
    removeReminder()

    let content = UNMutableNotificationContent()
    content.title = "Daily Better"
    content.body = "Pause for a moment. Your affirmation and mood check-in are waiting."
    content.sound = .default

    var components = DateComponents()
    components.hour = hour
    components.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(
      identifier: reminderIdentifier,
      content: content,
      trigger: trigger
    )

    try await UNUserNotificationCenter.current().add(request)
  }
}
