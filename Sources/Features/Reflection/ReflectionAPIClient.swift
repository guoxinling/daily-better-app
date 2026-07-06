import Foundation

protocol ReflectionAPITransport: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionReflectionAPITransport: ReflectionAPITransport {
  let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ReflectionAPIClientError.invalidResponse
    }
    return (data, httpResponse)
  }
}

enum ReflectionAPIClientError: Error, Equatable, Sendable {
  case unauthorized
  case badStatusCode(Int)
  case invalidResponse
}

actor ReflectionAPIClient {
  private let baseURL: URL
  private let transport: ReflectionAPITransport
  private let tokenStore: DeviceTokenStore
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    baseURL: URL,
    transport: ReflectionAPITransport = URLSessionReflectionAPITransport(),
    tokenStore: DeviceTokenStore
  ) {
    self.baseURL = baseURL
    self.transport = transport
    self.tokenStore = tokenStore
    self.encoder = JSONEncoder.reflectionAPIEncoder
    self.decoder = JSONDecoder.reflectionAPIDecoder
  }

  func fetchDeviceToken() async throws -> DeviceTokenRecord {
    let request = makeRequest(path: "api/device-token")
    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw error(for: response.statusCode)
    }
    return try decode(DeviceTokenRecord.self, from: data)
  }

  func requestReflection(
    token: String,
    request: ReflectionRequest,
    appVersion: String
  ) async throws -> RemoteReflectionPayload {
    do {
      return try await performReflectionRequest(
        token: token,
        request: request,
        appVersion: appVersion
      )
    } catch ReflectionAPIClientError.unauthorized {
      let refreshedToken = try await fetchDeviceToken()
      try tokenStore.write(refreshedToken)
      return try await performReflectionRequest(
        token: refreshedToken.deviceToken,
        request: request,
        appVersion: appVersion
      )
    }
  }

  private func performReflectionRequest(
    token: String,
    request: ReflectionRequest,
    appVersion: String
  ) async throws -> RemoteReflectionPayload {
    let body = RemoteReflectionRequestBody(
      mood: request.mood.rawValue,
      noteText: request.noteText,
      locale: request.localeIdentifier,
      requestID: request.requestID.uuidString,
      appVersion: appVersion,
      deviceToken: token
    )

    let urlRequest = try makeRequest(
      path: "api/reflect",
      token: token,
      body: body
    )
    let (data, response) = try await transport.send(urlRequest)
    guard (200..<300).contains(response.statusCode) else {
      throw error(for: response.statusCode)
    }
    return try decode(RemoteReflectionPayload.self, from: data)
  }

  private func makeRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func makeRequest<Body: Encodable>(
    path: String,
    token: String,
    body: Body
  ) throws -> URLRequest {
    var request = makeRequest(path: path)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try encoder.encode(body)
    return request
  }

  private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
    do {
      return try decoder.decode(type, from: data)
    } catch {
      throw ReflectionAPIClientError.invalidResponse
    }
  }

  private func error(for statusCode: Int) -> ReflectionAPIClientError {
    if statusCode == 401 {
      return .unauthorized
    }
    return .badStatusCode(statusCode)
  }
}

private struct RemoteReflectionRequestBody: Encodable {
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

extension JSONEncoder {
  static var reflectionAPIEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }
}

extension JSONDecoder {
  static var reflectionAPIDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
