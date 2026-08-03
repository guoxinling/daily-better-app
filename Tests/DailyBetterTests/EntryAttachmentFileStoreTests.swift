import UIKit
import XCTest
@testable import DailyBetter

final class EntryAttachmentFileStoreTests: XCTestCase {
  func testPreparingAndPersistingPhotoWritesLocalAttachmentFile() throws {
    let rootURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let store = EntryAttachmentFileStore(rootURL: rootURL)

    let draft = try store.prepareAttachment(from: try sampleJPEGData())
    let attachment = try store.persist(draft, sortIndex: 0)

    XCTAssertEqual(attachment.sortIndex, 0)
    XCTAssertGreaterThan(attachment.byteCount, 0)
    XCTAssertGreaterThan(attachment.width, 0)
    XCTAssertGreaterThan(attachment.height, 0)
    XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(for: attachment).path()))
    XCTAssertNotNil(UIImage(data: try Data(contentsOf: store.imageURL(for: attachment))))
  }

  func testDeletingAttachmentRemovesOnlyAppLocalFile() throws {
    let rootURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let store = EntryAttachmentFileStore(rootURL: rootURL)
    let attachment = try store.persist(
      try store.prepareAttachment(from: try sampleJPEGData()),
      sortIndex: 0
    )
    let fileURL = store.imageURL(for: attachment)

    try store.delete(fileNames: [attachment.fileName])

    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path()))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func sampleJPEGData() throws -> Data {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 18)).image { context in
      UIColor(red: 0.15, green: 0.48, blue: 0.36, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 24, height: 18))
    }
    return try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
  }
}
