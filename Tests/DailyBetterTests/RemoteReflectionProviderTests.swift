import Foundation
import XCTest
@testable import DailyBetter

final class RemoteReflectionProviderTests: XCTestCase {
  func testRemoteProviderBootstrapsTokenBeforeReflecting() async throws {
    let payload = RemoteReflectionPayload(
      reflectionText: "A calm reflection.",
      suggestedActionText: "Drink a glass of water.",
      source: .ai
    )
    let transport = ReflectionTransportSpy()
    transport.tokenResponses = [
      .success(.init(deviceToken: "token-1", issuedAt: .now, expiresAt: .distantFuture))
    ]
    transport.reflectResponses = [
      .success(payload)
    ]

    let store = InMemoryDeviceTokenStore()
    let provider = DeepSeekRemoteReflectionProvider(
      baseURL: URL(string: "https://example.vercel.app")!,
      tokenStore: store,
      transport: transport,
      appVersion: "1.0"
    )

    let result = try await provider.reflect(.init(
      mood: .anxious,
      noteText: "A lot is happening.",
      localeIdentifier: "en_US",
      requestID: UUID()
    ))

    XCTAssertEqual(result.source, .ai)
    XCTAssertEqual(result.reflectionText, payload.reflectionText)
    XCTAssertEqual(result.suggestedActionText, payload.suggestedActionText)
    XCTAssertEqual(transport.tokenRequests, 1)
    XCTAssertEqual(transport.reflectRequests.count, 1)
    XCTAssertEqual(transport.reflectRequests.first?.body.locale, "en_US")
    XCTAssertEqual(transport.reflectRequests.first?.body.noteText, "A lot is happening.")
    XCTAssertEqual(try store.read()?.deviceToken, "token-1")
  }

  func testExpiredTokenRefreshesBeforeRequest() async throws {
    let payload = RemoteReflectionPayload(
      reflectionText: "A grounded reflection.",
      suggestedActionText: "Take one slow breath.",
      source: .ai
    )
    let transport = ReflectionTransportSpy()
    transport.tokenResponses = [
      .success(.init(deviceToken: "fresh-token", issuedAt: .now, expiresAt: .distantFuture))
    ]
    transport.reflectResponses = [
      .success(payload)
    ]

    let store = InMemoryDeviceTokenStore(record: .init(
      deviceToken: "expired-token",
      issuedAt: .distantPast,
      expiresAt: .distantPast
    ))
    let provider = DeepSeekRemoteReflectionProvider(
      baseURL: URL(string: "https://example.vercel.app")!,
      tokenStore: store,
      transport: transport,
      appVersion: "1.0"
    )

    let result = try await provider.reflect(.init(
      mood: .low,
      noteText: "I need a reset.",
      localeIdentifier: "en_US",
      requestID: UUID()
    ))

    XCTAssertEqual(result.reflectionText, payload.reflectionText)
    XCTAssertEqual(result.suggestedActionText, payload.suggestedActionText)
    XCTAssertEqual(transport.tokenRequests, 1)
    XCTAssertEqual(transport.reflectRequests.count, 1)
    XCTAssertEqual(transport.reflectRequests.first?.authorizationHeader, "Bearer fresh-token")
    XCTAssertEqual(try store.read()?.deviceToken, "fresh-token")
  }

  func testUnauthorizedReflectRetriesOnceWithFreshToken() async throws {
    let payload = RemoteReflectionPayload(
      reflectionText: "You are already restarting well.",
      suggestedActionText: "Choose one kind next step.",
      source: .ai
    )
    let transport = ReflectionTransportSpy()
    transport.reflectResponses = [
      .failure(.unauthorized),
      .success(payload)
    ]
    transport.tokenResponses = [
      .success(.init(deviceToken: "fresh-token", issuedAt: .now, expiresAt: .distantFuture))
    ]

    let store = InMemoryDeviceTokenStore(record: .init(
      deviceToken: "stale-token",
      issuedAt: .now.addingTimeInterval(-60),
      expiresAt: .now.addingTimeInterval(3600)
    ))
    let provider = DeepSeekRemoteReflectionProvider(
      baseURL: URL(string: "https://example.vercel.app")!,
      tokenStore: store,
      transport: transport,
      appVersion: "1.0"
    )

    let result = try await provider.reflect(.init(
      mood: .overwhelmed,
      noteText: "Everything is competing for attention.",
      localeIdentifier: "en_US",
      requestID: UUID()
    ))

    XCTAssertEqual(result.source, .ai)
    XCTAssertEqual(result.reflectionText, payload.reflectionText)
    XCTAssertEqual(result.suggestedActionText, payload.suggestedActionText)
    XCTAssertEqual(transport.tokenRequests, 1)
    XCTAssertEqual(transport.reflectRequests.count, 2)
    XCTAssertEqual(transport.reflectRequests.first?.authorizationHeader, "Bearer stale-token")
    XCTAssertEqual(transport.reflectRequests.last?.authorizationHeader, "Bearer fresh-token")
    XCTAssertEqual(try store.read()?.deviceToken, "fresh-token")
  }

  func testRemoteFailureMapsToUnavailable() async {
    let transport = ReflectionTransportSpy()
    transport.reflectResponses = [.failure(.badStatusCode(502))]

    let store = InMemoryDeviceTokenStore(record: .init(
      deviceToken: "token-1",
      issuedAt: .now,
      expiresAt: .distantFuture
    ))
    let provider = DeepSeekRemoteReflectionProvider(
      baseURL: URL(string: "https://example.vercel.app")!,
      tokenStore: store,
      transport: transport,
      appVersion: "1.0"
    )

    do {
      _ = try await provider.reflect(.init(
        mood: .bright,
        noteText: "A good thing happened.",
        localeIdentifier: "en_US",
        requestID: UUID()
      ))
      XCTFail("Expected reflection to fail")
    } catch {
      XCTAssertEqual(error as? ReflectionError, .unavailable)
    }
  }
}

private final class InMemoryDeviceTokenStore: DeviceTokenStore, @unchecked Sendable {
  private let lock = NSLock()
  private var record: DeviceTokenRecord?

  init(record: DeviceTokenRecord? = nil) {
    self.record = record
  }

  func read() throws -> DeviceTokenRecord? {
    lock.withLock { record }
  }

  func write(_ record: DeviceTokenRecord) throws {
    lock.withLock {
      self.record = record
    }
  }

  func clear() throws {
    lock.withLock {
      record = nil
    }
  }
}

private final class ReflectionTransportSpy: ReflectionAPITransport, @unchecked Sendable {
  struct ReflectRequest: Equatable {
    let url: URL
    let authorizationHeader: String?
    let body: RequestBody
  }

  struct RequestBody: Decodable, Equatable {
    let mood: String
    let noteText: String
    let locale: String
    let requestID: String
    let appVersion: String
    let deviceToken: String

    enum CodingKeys: String, CodingKey {
      case mood
      case noteText
      case locale
      case requestID = "requestId"
      case appVersion
      case deviceToken
    }
  }

  var tokenResponses: [Result<DeviceTokenRecord, ReflectionAPIClientError>] = []
  var reflectResponses: [Result<RemoteReflectionPayload, ReflectionAPIClientError>] = []

  private let lock = NSLock()
  private(set) var tokenRequests = 0
  private(set) var reflectRequests: [ReflectRequest] = []
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    switch request.url?.path {
    case "/api/device-token":
      let response = try lock.withLock {
        tokenRequests += 1
        guard !tokenResponses.isEmpty else {
          throw ReflectionAPIClientError.invalidResponse
        }
        return tokenResponses.removeFirst()
      }
      let record = try response.get()
      let data = try encoder.encode(record)
      return (
        data,
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      )

    case "/api/reflect":
      let body = try XCTUnwrap(request.httpBody)
      let decodedBody = try JSONDecoder().decode(RequestBody.self, from: body)
      let response = try lock.withLock {
        reflectRequests.append(.init(
          url: request.url!,
          authorizationHeader: request.value(forHTTPHeaderField: "Authorization"),
          body: decodedBody
        ))
        guard !reflectResponses.isEmpty else {
          throw ReflectionAPIClientError.invalidResponse
        }
        return reflectResponses.removeFirst()
      }

      switch response {
      case .success(let payload):
        let data = try encoder.encode(payload)
        return (
          data,
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      case .failure(.unauthorized):
        return (
          Data(),
          HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        )
      case .failure(let error):
        throw error
      }

    default:
      throw ReflectionAPIClientError.invalidResponse
    }
  }
}

private extension NSLock {
  func withLock<T>(_ operation: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try operation()
  }
}
