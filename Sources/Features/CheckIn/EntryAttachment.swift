import Foundation
import SwiftData

@Model
final class EntryAttachment {
  var id: UUID
  var fileName: String
  var sortIndex: Int
  var createdAt: Date
  var width: Double
  var height: Double
  var byteCount: Int

  init(
    id: UUID = UUID(),
    fileName: String,
    sortIndex: Int = 0,
    createdAt: Date = .now,
    width: Double = 0,
    height: Double = 0,
    byteCount: Int = 0
  ) {
    self.id = id
    self.fileName = fileName
    self.sortIndex = sortIndex
    self.createdAt = createdAt
    self.width = width
    self.height = height
    self.byteCount = byteCount
  }
}
