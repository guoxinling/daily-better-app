import Foundation

enum ReflectionSource: String, Codable, Sendable {
  case local
  case ai
  case none
}

enum ReflectionStatus: String, Codable, Sendable {
  case none
  case pending
  case completed
  case failed
  case safetyRouted
}

enum Helpfulness: String, Codable, Sendable {
  case better
  case unchanged
  case unanswered
}

struct ReflectionRequest: Equatable, Sendable {
  let mood: CheckInMood
  let noteText: String
  let localeIdentifier: String
  let requestID: UUID
}

struct ReflectionResult: Equatable, Sendable {
  let reflectionText: String
  let suggestedActionText: String
  let source: ReflectionSource
}

enum ReflectionError: Error, Equatable, Sendable {
  case unavailable
  case invalidResponse
  case safetyRouted
}
