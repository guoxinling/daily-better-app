import Foundation
import Security

protocol DeviceTokenStore: Sendable {
  func read() throws -> DeviceTokenRecord?
  func write(_ record: DeviceTokenRecord) throws
  func clear() throws
}

final class KeychainDeviceTokenStore: DeviceTokenStore, @unchecked Sendable {
  private let service: String
  private let account: String
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    service: String = "com.guoxl.DailyBetter.reflection",
    account: String = "device-token"
  ) {
    self.service = service
    self.account = account
    self.encoder = JSONEncoder.reflectionAPIEncoder
    self.decoder = JSONDecoder.reflectionAPIDecoder
  }

  func read() throws -> DeviceTokenRecord? {
    var query = keychainQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard let data = item as? Data else {
        throw KeychainDeviceTokenStoreError.unexpectedData
      }
      return try decoder.decode(DeviceTokenRecord.self, from: data)
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainDeviceTokenStoreError.osStatus(status)
    }
  }

  func write(_ record: DeviceTokenRecord) throws {
    let data = try encoder.encode(record)
    var attributes = keychainQuery()
    attributes[kSecValueData as String] = data

    let addStatus = SecItemAdd(attributes as CFDictionary, nil)
    if addStatus == errSecSuccess {
      return
    }

    guard addStatus == errSecDuplicateItem else {
      throw KeychainDeviceTokenStoreError.osStatus(addStatus)
    }

    let updateStatus = SecItemUpdate(
      keychainQuery() as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    guard updateStatus == errSecSuccess else {
      throw KeychainDeviceTokenStoreError.osStatus(updateStatus)
    }
  }

  func clear() throws {
    let status = SecItemDelete(keychainQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainDeviceTokenStoreError.osStatus(status)
    }
  }

  private func keychainQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}

enum KeychainDeviceTokenStoreError: Error {
  case osStatus(OSStatus)
  case unexpectedData
}
