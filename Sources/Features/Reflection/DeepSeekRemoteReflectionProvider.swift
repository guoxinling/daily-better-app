import Foundation

struct DeepSeekRemoteReflectionProvider: ReflectionProviding {
  private let client: ReflectionAPIClient
  private let tokenStore: DeviceTokenStore
  private let appVersion: String

  init(
    baseURL: URL,
    tokenStore: DeviceTokenStore,
    transport: ReflectionAPITransport = URLSessionReflectionAPITransport(),
    appVersion: String = "1.0"
  ) {
    self.client = ReflectionAPIClient(
      baseURL: baseURL,
      transport: transport,
      tokenStore: tokenStore
    )
    self.tokenStore = tokenStore
    self.appVersion = appVersion
  }

  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    do {
      let token = try await validToken()
      let payload = try await client.requestReflection(
        token: token.deviceToken,
        request: request,
        appVersion: appVersion
      )

      return ReflectionResult(
        reflectionText: payload.reflectionText,
        suggestedActionText: payload.suggestedActionText,
        source: .ai
      )
    } catch let error as CancellationError {
      throw error
    } catch {
      throw ReflectionError.unavailable
    }
  }

  private func validToken() async throws -> DeviceTokenRecord {
    if let record = try tokenStore.read(), !record.isExpired {
      return record
    }

    let record = try await client.fetchDeviceToken()
    try tokenStore.write(record)
    return record
  }
}
