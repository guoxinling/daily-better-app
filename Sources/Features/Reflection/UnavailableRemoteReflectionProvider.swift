struct UnavailableRemoteReflectionProvider: ReflectionProviding {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    throw ReflectionError.unavailable
  }
}
