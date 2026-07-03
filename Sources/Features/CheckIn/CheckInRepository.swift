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
    self.context = ModelContext(context.container)
  }

  func save(_ entry: CheckInEntry) throws {
    do {
      context.insert(entry)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  func deleteAll() throws {
    do {
      try context.delete(model: CheckInEntry.self)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }
}
