protocol ReflectionProviding: Sendable {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult
}
