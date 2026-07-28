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
    ReflectionDebugLog.logRequest(request)
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      ReflectionDebugLog.logTransportError(error, request: request)
      throw error
    }
    guard let httpResponse = response as? HTTPURLResponse else {
      ReflectionDebugLog.logInvalidResponse(request)
      throw ReflectionAPIClientError.invalidResponse
    }
    ReflectionDebugLog.logResponse(httpResponse, request: request)
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
      ReflectionDebugLog.logRejectedStatus(response.statusCode, request: request, data: data)
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
    ReflectionDebugLog.logRequestBodySummary(body)

    let urlRequest = try makeRequest(
      path: "api/reflect",
      token: token,
      body: body
    )
    let (data, response) = try await transport.send(urlRequest)
    guard (200..<300).contains(response.statusCode) else {
      ReflectionDebugLog.logRejectedStatus(response.statusCode, request: urlRequest, data: data)
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

enum ReflectionDebugLog {
  static func logRequest(_ request: URLRequest) {
    #if DEBUG
    print("[ReflectionAPI] request \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "<missing-url>")")
    #endif
  }

  fileprivate static func logRequestBodySummary(_ body: RemoteReflectionRequestBody) {
    #if DEBUG
    print(
      "[ReflectionAPI] request body summary mood=\(body.mood) noteLength=\(body.noteText.count) locale=\(body.locale) localeLength=\(body.locale.count) appVersion=\(body.appVersion) appVersionLength=\(body.appVersion.count) requestId=\(body.requestID) tokenLength=\(body.deviceToken.count)"
    )
    #endif
  }

  static func logResponse(_ response: HTTPURLResponse, request: URLRequest) {
    #if DEBUG
    print("[ReflectionAPI] response \(response.statusCode) \(request.url?.absoluteString ?? "<missing-url>")")
    #endif
  }

  static func logRejectedStatus(_ statusCode: Int, request: URLRequest, data: Data) {
    #if DEBUG
    let body = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
    print("[ReflectionAPI] rejected status \(statusCode) \(request.url?.absoluteString ?? "<missing-url>") body=\(body)")
    #endif
  }

  static func logTransportError(_ error: Error, request: URLRequest) {
    #if DEBUG
    let nsError = error as NSError
    print("[ReflectionAPI] transport error \(nsError.domain)(\(nsError.code)) \(request.url?.absoluteString ?? "<missing-url>") \(nsError.localizedDescription)")
    #endif
  }

  static func logInvalidResponse(_ request: URLRequest) {
    #if DEBUG
    print("[ReflectionAPI] invalid response \(request.url?.absoluteString ?? "<missing-url>")")
    #endif
  }

  static func logProviderError(_ error: Error) {
    #if DEBUG
    let nsError = error as NSError
    print("[ReflectionAPI] provider failed \(nsError.domain)(\(nsError.code)) \(nsError.localizedDescription)")
    #endif
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
