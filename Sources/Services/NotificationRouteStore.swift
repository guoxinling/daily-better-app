import Observation

@MainActor
@Observable
final class NotificationRouteStore {
  static let shared = NotificationRouteStore()

  var pendingDestination: AppDestination?

  private init() {}
}
