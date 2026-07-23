import Foundation

enum EntryComposerMode {
  case create(createdAt: Date)
  case edit(CheckInEntry)

  var createdAt: Date {
    switch self {
    case .create(let createdAt):
      createdAt
    case .edit(let entry):
      entry.createdAt
    }
  }
}
