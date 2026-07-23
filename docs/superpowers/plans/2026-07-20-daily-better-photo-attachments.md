# Daily Better Photo Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users attach up to four private, on-device photos to a journal entry and view, export, edit, and delete them without sending image data to the reflection backend.

**Architecture:** `EntryAttachment` stores only metadata in SwiftData while `EntryAttachmentFileStore` owns staged and committed image files under Application Support. The composer keeps `DraftAttachment` values until Save/Reflect succeeds, then coordinates file promotion with entry persistence and cleanup. Timeline shows only an attachment count; Entry Detail renders the images.

**Tech Stack:** Swift 5, SwiftUI, PhotosUI, ImageIO/UIKit image processing, SwiftData, XCTest, XCUITest, XcodeGen, iOS 17+

## Global Constraints

- Complete the Timeline-first core plan before starting this plan.
- Maximum four images per entry.
- Normalize orientation, limit the long edge to 2048 pixels, and encode JPEG near 0.82 quality.
- Store files only in the app's private Application Support directory.
- Store filenames and dimensions in SwiftData; never store full image data in SwiftData.
- Never include images or image-derived text in `ReflectionRequest`.
- Draft cancellation, failed persistence, entry deletion, and Delete All must remove the correct files.
- Promoting a draft copies it into committed storage; the staged source remains available until SwiftData save succeeds.
- Export includes the text manifest and committed attachment files.
- Use `iPhone 17 Pro, iOS 26.5` for Simulator commands.

---

### Task 1: Add attachment metadata to the SwiftData graph

**Files:**
- Create: `Sources/Features/Attachments/EntryAttachment.swift`
- Modify: `Sources/Features/CheckIn/CheckInEntry.swift`
- Modify: `Sources/App/DailyBetterApp.swift`
- Modify: `Tests/DailyBetterTests/CheckInEntryTests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `EntryAttachment(id:filename:pixelWidth:pixelHeight:displayOrder:)`
- Produces: `CheckInEntry.attachments: [EntryAttachment]`

- [ ] **Step 1: Write the failing model relationship test**

```swift
func testEntryStoresAttachmentsInDisplayOrder() {
  let second = EntryAttachment(
    filename: "second.jpg", pixelWidth: 1200, pixelHeight: 900, displayOrder: 1
  )
  let first = EntryAttachment(
    filename: "first.jpg", pixelWidth: 900, pixelHeight: 1200, displayOrder: 0
  )
  let entry = CheckInEntry(mood: .bright, attachments: [second, first])

  XCTAssertEqual(entry.orderedAttachments.map(\.filename), ["first.jpg", "second.jpg"])
}
```

- [ ] **Step 2: Run the model test and verify missing types**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInEntryTests
```

Expected: FAIL because `EntryAttachment` and the relationship are absent.

- [ ] **Step 3: Add the attachment model**

```swift
import Foundation
import SwiftData

@Model
final class EntryAttachment {
  var id: UUID
  var filename: String
  var pixelWidth: Int
  var pixelHeight: Int
  var displayOrder: Int
  var entry: CheckInEntry?

  init(
    id: UUID = UUID(),
    filename: String,
    pixelWidth: Int,
    pixelHeight: Int,
    displayOrder: Int
  ) {
    self.id = id
    self.filename = filename
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
    self.displayOrder = displayOrder
  }
}
```

Add to `CheckInEntry`:

```swift
@Relationship(deleteRule: .cascade, inverse: \EntryAttachment.entry)
var attachments: [EntryAttachment]

var orderedAttachments: [EntryAttachment] {
  attachments.sorted { $0.displayOrder < $1.displayOrder }
}
```

Default `attachments` to `[]` in the initializer so existing call sites remain source-compatible.

- [ ] **Step 4: Register the model and regenerate**

Add `EntryAttachment.self` to the app `ModelContainer`, then run:

```bash
xcodegen generate
```

Expected: project generation succeeds.

- [ ] **Step 5: Run model and migration tests**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInEntryTests \
  -only-testing:DailyBetterTests/CheckInMigrationServiceTests
```

Expected: PASS and existing entries initialize with an empty attachment relationship.

- [ ] **Step 6: Commit the metadata model**

```bash
git add project.yml DailyBetter.xcodeproj Sources/App/DailyBetterApp.swift \
  Sources/Features/Attachments/EntryAttachment.swift \
  Sources/Features/CheckIn/CheckInEntry.swift \
  Tests/DailyBetterTests/CheckInEntryTests.swift
git commit -m "feat: add journal attachment metadata"
```

### Task 2: Build deterministic staged-file storage

**Files:**
- Create: `Sources/Features/Attachments/DraftAttachment.swift`
- Create: `Sources/Features/Attachments/EntryAttachmentFileStore.swift`
- Create: `Tests/DailyBetterTests/EntryAttachmentFileStoreTests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `DraftAttachment`
- Produces: `EntryAttachmentFileStoring.stageImageData(_:id:)`
- Produces: `commit(_:)`, `discard(_:)`, `delete(filename:)`, `url(for:)`, and `deleteAll()`

- [ ] **Step 1: Write failing file-store tests**

Use a temporary root URL and a generated 3000-by-1500 test image. Assert:

```swift
let draft = try store.stageImageData(sourceJPEG, id: fixedID)
XCTAssertTrue(FileManager.default.fileExists(atPath: draft.stagedURL.path))
XCTAssertEqual(max(draft.pixelWidth, draft.pixelHeight), 2048)

let filename = try store.promote(draft)
XCTAssertEqual(filename, "\(fixedID.uuidString).jpg")
XCTAssertTrue(FileManager.default.fileExists(atPath: draft.stagedURL.path))
XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: filename).path))

store.finalize(draft)
XCTAssertFalse(FileManager.default.fileExists(atPath: draft.stagedURL.path))
```

Add tests for discard, rollback of a promoted committed copy while retaining staging, one-file delete, all-file delete, invalid image rejection, and duplicate promotion replacement.

- [ ] **Step 2: Run the new tests and verify missing storage types**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/EntryAttachmentFileStoreTests
```

Expected: FAIL because the file store does not exist.

- [ ] **Step 3: Define the draft and protocol**

```swift
struct DraftAttachment: Identifiable, Equatable {
  let id: UUID
  let stagedURL: URL
  let pixelWidth: Int
  let pixelHeight: Int
}

protocol EntryAttachmentFileStoring: Sendable {
  func stageImageData(_ data: Data, id: UUID) throws -> DraftAttachment
  func promote(_ draft: DraftAttachment) throws -> String
  func rollbackPromotion(filename: String)
  func finalize(_ draft: DraftAttachment)
  func discard(_ draft: DraftAttachment)
  func delete(filename: String)
  func deleteAll()
  func url(for filename: String) -> URL
}
```

- [ ] **Step 4: Implement image normalization and directories**

`EntryAttachmentFileStore` receives a root URL in tests and defaults to:

```swift
FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
  .appending(path: "DailyBetter/Attachments", directoryHint: .isDirectory)
```

Create `Staging` and `Committed` subdirectories. Decode with `UIImage(data:)`, normalize orientation by drawing into a renderer, scale by `min(1, 2048 / longEdge)`, and encode with `jpegData(compressionQuality: 0.82)`. Write staging files atomically. `promote(_:)` copies rather than moves the staged file; `finalize(_:)` removes staging only after model save succeeds; `rollbackPromotion(filename:)` removes only the copied committed file.

- [ ] **Step 5: Run file-store tests**

Run the Step 2 test command.

Expected: PASS with no files left after each cleanup assertion.

- [ ] **Step 6: Commit file storage**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Attachments/DraftAttachment.swift \
  Sources/Features/Attachments/EntryAttachmentFileStore.swift \
  Tests/DailyBetterTests/EntryAttachmentFileStoreTests.swift
git commit -m "feat: add private journal image storage"
```

### Task 3: Coordinate attachments with create, edit, and failure recovery

**Files:**
- Modify: `Sources/Features/CheckIn/CheckInDraft.swift`
- Modify: `Sources/Features/CheckIn/CheckInRepository.swift`
- Modify: `Sources/Features/CheckIn/CheckInViewModel.swift`
- Modify: `Tests/DailyBetterTests/CheckInRepositoryTests.swift`
- Modify: `Tests/DailyBetterTests/CheckInViewModelTests.swift`

**Interfaces:**
- Produces: `CheckInViewModel.draftAttachments`
- Produces: `addAttachment(_:)`, `removeAttachment(id:)`, `discardDraft()`
- Preserves: `ReflectionRequest` fields remain mood, note, locale, and request ID only.

- [ ] **Step 1: Write failing attachment lifecycle tests**

```swift
func testReflectionRequestNeverContainsAttachmentData() async {
  let viewModel = makeViewModel(fileStore: fileStore)
  viewModel.selectedMood = .bright
  viewModel.noteText = "A good moment"
  viewModel.addAttachment(stagedDraft)

  await viewModel.reflect()

  XCTAssertEqual(remoteProvider.requests.first?.noteText, "A good moment")
  XCTAssertEqual(repository.entries.first?.attachments.count, 1)
}

func testFailedReflectionPreservesStagedAttachment() async {
  remoteProvider.result = .failure(.unavailable)
  await viewModel.reflect()

  XCTAssertEqual(viewModel.draftAttachments.map(\.id), [stagedDraft.id])
  XCTAssertTrue(fileStore.stagedIDs.contains(stagedDraft.id))
}

func testDiscardRemovesOnlyNewDraftFiles() {
  viewModel.discardDraft()
  XCTAssertTrue(fileStore.discardedIDs.contains(stagedDraft.id))
  XCTAssertFalse(fileStore.deletedCommittedFilenames.contains(existingFilename))
}
```

Add an edit test proving attachment-only edits preserve existing reflection text.

- [ ] **Step 2: Run focused tests and verify failures**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInRepositoryTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Expected: FAIL because drafts and attachment persistence are absent.

- [ ] **Step 3: Extend draft state without changing the backend DTO**

Add `draftAttachments: [DraftAttachment]` to `CheckInDraft` and ViewModel. Limit `addAttachment` to four; expose `canAddAttachment`. Do not add attachment fields to `ReflectionRequest`, `ReflectionAPIClient`, or backend routes.

- [ ] **Step 4: Promote files and persist metadata as one coordinated operation**

Before repository save, promote each new draft and build metadata:

```swift
let committed = try draftAttachments.enumerated().map { index, draft in
  EntryAttachment(
    id: draft.id,
    filename: try fileStore.promote(draft),
    pixelWidth: draft.pixelWidth,
    pixelHeight: draft.pixelHeight,
    displayOrder: index
  )
}
```

If model persistence succeeds, call `finalize(_:)` for each promoted draft. If model persistence fails, call `rollbackPromotion(filename:)` for every filename promoted by that attempt and keep the untouched staged drafts in memory for retry. For edits, calculate removed committed filenames but delete them only after the model update succeeds. Add a failure test that retries the same draft after rollback and succeeds without restaging image data.

- [ ] **Step 5: Run lifecycle tests**

Run the Step 2 command.

Expected: PASS for successful create, successful edit, failed reflection, failed save, and explicit discard.

- [ ] **Step 6: Commit lifecycle coordination**

```bash
git add Sources/Features/CheckIn/CheckInDraft.swift \
  Sources/Features/CheckIn/CheckInRepository.swift \
  Sources/Features/CheckIn/CheckInViewModel.swift \
  Tests/DailyBetterTests/CheckInRepositoryTests.swift \
  Tests/DailyBetterTests/CheckInViewModelTests.swift
git commit -m "feat: persist journal photo drafts safely"
```

### Task 4: Add PhotosPicker and composer thumbnails

**Files:**
- Create: `Sources/Features/Attachments/AttachmentPickerButton.swift`
- Create: `Sources/Features/Attachments/AttachmentThumbnailStrip.swift`
- Modify: `Sources/Features/CheckIn/CheckInView.swift`
- Modify: `Tests/DailyBetterUITests/CheckInFlowUITests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces identifiers: `checkIn.addPhoto`, `checkIn.attachment.<uuid>`, `checkIn.attachment.remove.<uuid>`
- Consumes: `CheckInViewModel.addAttachment(_:)` and `removeAttachment(id:)`

- [ ] **Step 1: Add failing UI coverage using seeded draft attachments**

Add `initialDraftAttachments` to the `CheckInViewModel` initializer. In `RootTabView`, when `ProcessInfo.processInfo.arguments` contains `-seed-draft-attachment`, create one deterministic staged fixture through the injected file store and pass it to the composer ViewModel; production passes an empty array. Then assert:

```swift
func testComposerShowsAndRemovesAttachmentThumbnail() {
  let app = launchComposer(additionalArguments: ["-seed-draft-attachment"])
  let thumbnail = app.images.matching(identifier: "checkIn.attachment.seeded").firstMatch
  XCTAssertTrue(thumbnail.waitForExistence(timeout: 3))

  app.buttons["checkIn.attachment.remove.seeded"].tap()
  XCTAssertFalse(thumbnail.exists)
  XCTAssertTrue(app.buttons["checkIn.addPhoto"].isHittable)
}
```

- [ ] **Step 2: Run Check In UI tests and verify missing photo controls**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/CheckInFlowUITests
```

Expected: FAIL because the photo control and seeded thumbnail are absent.

- [ ] **Step 3: Add PhotosPicker loading**

Use `PhotosPicker(selection:maxSelectionCount:matching:)` with images only. For each selected item:

```swift
guard let data = try await item.loadTransferable(type: Data.self) else {
  throw AttachmentError.unreadableImage
}
let draft = try fileStore.stageImageData(data, id: UUID())
viewModel.addAttachment(draft)
```

Disable the picker when four attachments are present. Show a non-destructive alert if one selected item cannot be loaded; keep successful selections.

- [ ] **Step 4: Render removable thumbnails**

Use a horizontal strip below the editor. Each thumbnail is 72 points, clipped to a 16-point continuous rounded rectangle, has a visible remove button, and loads from the staged or committed local URL. Give the strip an accessibility label such as `2 attached photos`.

- [ ] **Step 5: Regenerate and run UI tests**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/CheckInFlowUITests
```

Expected: PASS, including long-text keyboard layout with thumbnails present.

- [ ] **Step 6: Commit composer photo UI**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Attachments/AttachmentPickerButton.swift \
  Sources/Features/Attachments/AttachmentThumbnailStrip.swift \
  Sources/Features/CheckIn/CheckInView.swift \
  Tests/DailyBetterUITests/CheckInFlowUITests.swift
git commit -m "feat: add photos to journal composer"
```

### Task 5: Render, export, and delete committed attachments

**Files:**
- Create: `Sources/Features/Attachments/EntryAttachmentGallery.swift`
- Modify: `Sources/Features/Timeline/EntryDetailView.swift`
- Modify: `Sources/Features/Timeline/TimelineEntryRow.swift`
- Modify: `Sources/Services/TimelineExportService.swift`
- Modify: `Sources/Views/Settings/SettingsView.swift`
- Modify: `Sources/Features/CheckIn/CheckInRepository.swift`
- Create: `Tests/DailyBetterTests/TimelineAttachmentExportTests.swift`
- Modify: `Tests/DailyBetterUITests/TimelineUITests.swift`
- Modify: `Tests/DailyBetterUITests/DataControlsUITests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `TimelineExportPackage.urls: [URL]`
- Produces identifiers: `timeline.entry.attachment.badge`, `entry.attachment.<uuid>`

- [ ] **Step 1: Write failing export and detail tests**

```swift
func testExportPackageContainsManifestAndAttachmentFiles() throws {
  let package = try TimelineExportService.preparePackage(
    entries: [entryWithTwoAttachments],
    legacyAffirmations: [],
    fileStore: fileStore,
    temporaryDirectory: temporaryDirectory
  )

  XCTAssertEqual(package.urls.count, 3)
  XCTAssertTrue(package.urls.first!.lastPathComponent.hasSuffix(".txt"))
  XCTAssertEqual(Set(package.urls.dropFirst().map(\.lastPathComponent)), ["one.jpg", "two.jpg"])
}
```

Add UI assertions that Timeline shows `2 photos`, detail shows two image identifiers, Delete Entry removes the row, and Delete All removes attachment files.

- [ ] **Step 2: Run tests and verify missing gallery/export package**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/TimelineAttachmentExportTests \
  -only-testing:DailyBetterUITests/TimelineUITests \
  -only-testing:DailyBetterUITests/DataControlsUITests
```

Expected: FAIL because attachment gallery, package export, and file cleanup are absent.

- [ ] **Step 3: Add Timeline count and detail gallery**

Timeline renders only:

```swift
if !entry.attachments.isEmpty {
  Label("\(entry.attachments.count) photos", systemImage: "photo.on.rectangle")
    .accessibilityIdentifier("timeline.entry.attachment.badge")
}
```

Detail uses an adaptive two-column `LazyVGrid`, preserves aspect ratio from stored dimensions, and loads local files through the file store. Missing files render a neutral placeholder rather than crashing.

- [ ] **Step 4: Return a multi-item export package**

```swift
struct TimelineExportPackage {
  let manifestURL: URL
  let attachmentURLs: [URL]
  var urls: [URL] { [manifestURL] + attachmentURLs }
}
```

Copy committed image files into a unique temporary export directory using collision-safe names containing entry ID and attachment ID. Create `ActivityShareView: UIViewControllerRepresentable` with `let items: [Any]`; `makeUIViewController` returns `UIActivityViewController(activityItems: items, applicationActivities: nil)`. Update `ExportTimelineView` to pass `package.urls` as the complete items array.

- [ ] **Step 5: Integrate cleanup with entry and global deletion**

Before deleting model objects, capture filenames. Delete SwiftData objects and save. Only after save succeeds, delete captured committed files. `Delete All Entries` calls the repository deletion and then `fileStore.deleteAll()`; if the model deletion fails, leave files untouched.

- [ ] **Step 6: Run attachment regressions**

Run the Step 2 command, then:

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests \
  -only-testing:DailyBetterUITests/CheckInFlowUITests \
  -only-testing:DailyBetterUITests/TimelineUITests \
  -only-testing:DailyBetterUITests/DataControlsUITests
```

Expected: `** TEST SUCCEEDED **` and no attachment filename appears in reflection-provider request logs.

- [ ] **Step 7: Commit attachment reading and lifecycle completion**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Attachments/EntryAttachmentGallery.swift \
  Sources/Features/Timeline/EntryDetailView.swift \
  Sources/Features/Timeline/TimelineEntryRow.swift \
  Sources/Services/TimelineExportService.swift \
  Sources/Views/Settings/SettingsView.swift \
  Sources/Features/CheckIn/CheckInRepository.swift \
  Tests/DailyBetterTests/TimelineAttachmentExportTests.swift \
  Tests/DailyBetterUITests/TimelineUITests.swift \
  Tests/DailyBetterUITests/DataControlsUITests.swift
git commit -m "feat: complete private journal photo lifecycle"
```
