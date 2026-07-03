import SwiftData

@MainActor
protocol CheckInRepository: AnyObject {
  func save(_ entry: CheckInEntry) throws
  func deleteAll() throws
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func save(_ entry: CheckInEntry) throws {
    context.insert(entry)
    try context.save()
  }

  func deleteAll() throws {
    try context.delete(model: CheckInEntry.self)
    try context.save()
  }
}
