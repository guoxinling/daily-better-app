import Foundation
import UIKit

struct DraftAttachment: Identifiable, Equatable {
  let id: UUID
  let previewData: Data
  let storedFileName: String?
  let width: Double
  let height: Double
  let byteCount: Int

  var identityToken: String {
    storedFileName ?? id.uuidString
  }
}

protocol EntryAttachmentFileDeleting: AnyObject {
  func delete(fileNames: [String]) throws
}

protocol EntryAttachmentFileStoring: EntryAttachmentFileDeleting {
  func prepareAttachment(from data: Data) throws -> DraftAttachment
  func persist(_ attachment: DraftAttachment, sortIndex: Int) throws -> EntryAttachment
  func imageURL(for attachment: EntryAttachment) -> URL
  func draftAttachment(for attachment: EntryAttachment) -> DraftAttachment?
}

final class EntryAttachmentFileStore: EntryAttachmentFileStoring {
  private let rootURL: URL
  private let fileManager: FileManager

  init(rootURL: URL? = nil, fileManager: FileManager = .default) {
    self.fileManager = fileManager
    if let rootURL {
      self.rootURL = rootURL
    } else {
      let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? fileManager.temporaryDirectory
      self.rootURL = baseURL
        .appending(path: "DailyBetter", directoryHint: .isDirectory)
        .appending(path: "EntryAttachments", directoryHint: .isDirectory)
    }
  }

  func prepareAttachment(from data: Data) throws -> DraftAttachment {
    guard let image = UIImage(data: data) else {
      throw EntryAttachmentFileStoreError.invalidImageData
    }

    let normalizedImage = image.normalizedForDailyBetter(maxDimension: 1_600)
    guard let jpegData = normalizedImage.jpegData(compressionQuality: 0.82) else {
      throw EntryAttachmentFileStoreError.encodingFailed
    }

    return DraftAttachment(
      id: UUID(),
      previewData: jpegData,
      storedFileName: nil,
      width: normalizedImage.size.width * normalizedImage.scale,
      height: normalizedImage.size.height * normalizedImage.scale,
      byteCount: jpegData.count
    )
  }

  func persist(_ attachment: DraftAttachment, sortIndex: Int) throws -> EntryAttachment {
    try ensureDirectoryExists()

    let fileName = attachment.storedFileName ?? "\(UUID().uuidString).jpg"
    if attachment.storedFileName == nil {
      try attachment.previewData.write(to: rootURL.appending(path: fileName), options: .atomic)
    }

    return EntryAttachment(
      fileName: fileName,
      sortIndex: sortIndex,
      width: attachment.width,
      height: attachment.height,
      byteCount: attachment.byteCount
    )
  }

  func imageURL(for attachment: EntryAttachment) -> URL {
    rootURL.appending(path: attachment.fileName)
  }

  func draftAttachment(for attachment: EntryAttachment) -> DraftAttachment? {
    let url = imageURL(for: attachment)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return DraftAttachment(
      id: attachment.id,
      previewData: data,
      storedFileName: attachment.fileName,
      width: attachment.width,
      height: attachment.height,
      byteCount: attachment.byteCount
    )
  }

  func delete(fileNames: [String]) throws {
    for fileName in Set(fileNames) where !fileName.isEmpty {
      let url = rootURL.appending(path: fileName)
      guard fileManager.fileExists(atPath: url.path) else { continue }
      try fileManager.removeItem(at: url)
    }
  }

  private func ensureDirectoryExists() throws {
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
  }
}

enum EntryAttachmentFileStoreError: Error {
  case invalidImageData
  case encodingFailed
}

private extension UIImage {
  func normalizedForDailyBetter(maxDimension: CGFloat) -> UIImage {
    let fixedImage = fixedOrientation()
    let largestSide = max(fixedImage.size.width, fixedImage.size.height)
    guard largestSide > maxDimension else { return fixedImage }

    let scaleRatio = maxDimension / largestSide
    let targetSize = CGSize(
      width: fixedImage.size.width * scaleRatio,
      height: fixedImage.size.height * scaleRatio
    )
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      fixedImage.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  func fixedOrientation() -> UIImage {
    guard imageOrientation != .up else { return self }
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
