import Foundation

struct DeviceTokenRecord: Codable, Equatable, Sendable {
  let deviceToken: String
  let issuedAt: Date
  let expiresAt: Date

  var isExpired: Bool {
    expiresAt <= .now
  }
}
