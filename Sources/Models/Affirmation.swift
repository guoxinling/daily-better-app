import Foundation
import SwiftData

@Model
final class Affirmation {
  var id: UUID
  var text: String
  var categoryKey: String
  var isFavorite: Bool
  var isCustom: Bool
  var createdAt: Date

  init(
    id: UUID = UUID(),
    text: String,
    category: AffirmationCategory,
    isFavorite: Bool = false,
    isCustom: Bool = false,
    createdAt: Date = .now
  ) {
    self.id = id
    self.text = text
    self.categoryKey = category.rawValue
    self.isFavorite = isFavorite
    self.isCustom = isCustom
    self.createdAt = createdAt
  }

  var category: AffirmationCategory {
    AffirmationCategory(rawValue: categoryKey) ?? .growth
  }
}
