import Foundation
import Observation

@MainActor
@Observable
final class NotificationRouteStore {
  static let shared = NotificationRouteStore()

  var pendingDestination: AppDestination?
  var pendingEntryID: UUID?

  private init() {}
}
