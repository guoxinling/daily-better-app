# Daily Better Timeline-First Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-tab root with a Timeline-first journal flow, a full-screen long-form composer, a balanced six-mood model, and a complete saved-entry detail/edit experience.

**Architecture:** `RootTabView` becomes a Timeline navigation coordinator that owns full-screen composer/detail presentation. Existing reflection providers remain unchanged; `CheckInViewModel` gains explicit create/edit modes and the repository gains update/delete operations. A version-2 migration rewrites production mood keys before the new enum becomes the presentation source.

**Tech Stack:** Swift 5, SwiftUI, Observation, SwiftData, XCTest, XCUITest, XcodeGen, iOS 17+

## Global Constraints

- Timeline is the only root destination; no root tab bar may remain.
- New Entry and Entry Detail are full-screen secondary pages; Settings is pushed from Timeline.
- One mood is required; note text is optional.
- Buttons use SF Pro Semibold; primary actions use the approved soft green gradient.
- Timeline note previews are limited to three lines; detail text is never truncated.
- Mood-only reflection remains local; written reflection keeps the existing remote provider contract.
- Reflection failure preserves the draft and offers retry, save without reflection, and cancel.
- Existing entries must migrate deterministically to migration version 2.
- Use `iPhone 17 Pro, iOS 26.5` for the repeatable Simulator commands in this plan.
- Generate the Xcode project with `xcodegen generate` whenever source membership or project settings change.

---

### Task 1: Introduce the balanced mood model and production migration

**Files:**
- Modify: `Sources/Features/CheckIn/CheckInMood.swift`
- Modify: `Sources/Features/CheckIn/CheckInEntry.swift`
- Modify: `Sources/Services/CheckInMigrationService.swift`
- Modify: `Tests/DailyBetterTests/CheckInEntryTests.swift`
- Modify: `Tests/DailyBetterTests/CheckInMigrationServiceTests.swift`

**Interfaces:**
- Produces: `CheckInMood.bright`, `.calm`, `.okay`, `.anxious`, `.low`, `.overwhelmed`
- Produces: `CheckInMood.init(storedKey:) -> CheckInMood`
- Produces: `CheckInMigrationService.currentVersion == 2`
- Preserves: `CheckInEntry.moodKey: String`

- [ ] **Step 1: Replace mood expectations with failing version-2 tests**

```swift
func testAllMoodsHaveApprovedStableLabelsAndEmoji() {
  XCTAssertEqual(CheckInMood.allCases.map(\.rawValue), [
    "bright", "calm", "okay", "anxious", "low", "overwhelmed"
  ])
  XCTAssertEqual(CheckInMood.allCases.map(\.title), [
    "Bright", "Calm", "Okay", "Anxious", "Low", "Overwhelmed"
  ])
  XCTAssertEqual(CheckInMood.allCases.map(\.emoji), ["😊", "🙂", "😐", "😰", "😔", "😣"])
}

func testUnknownStoredMoodPresentsAsOkayWithoutRewritingRawValue() {
  let entry = CheckInEntry(mood: .anxious)
  entry.moodKey = "future-mood"

  XCTAssertEqual(entry.mood, .okay)
  XCTAssertEqual(entry.moodKey, "future-mood")
}
```

Add a migration test that seeds all six current keys at version 1, runs twice, and expects:

```swift
XCTAssertEqual(storedEntries.map(\.moodKey).sorted(), [
  "anxious", "bright", "low", "low", "overwhelmed", "overwhelmed"
])
XCTAssertEqual(storedPreferences.migrationVersion, 2)
XCTAssertEqual(storedEntries.count, 6)
```

- [ ] **Step 2: Run the tests and verify the old model fails**

Run:

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInEntryTests \
  -only-testing:DailyBetterTests/CheckInMigrationServiceTests
```

Expected: FAIL because `bright`, `calm`, and `okay` do not exist and `currentVersion` is 1.

- [ ] **Step 3: Implement the new enum and non-positive fallback**

```swift
enum CheckInMood: String, CaseIterable, Codable, Identifiable, Sendable {
  case bright, calm, okay, anxious, low, overwhelmed

  var id: String { rawValue }

  init(storedKey: String) {
    self = CheckInMood(rawValue: storedKey) ?? .okay
  }

  var title: String {
    switch self {
    case .bright: "Bright"
    case .calm: "Calm"
    case .okay: "Okay"
    case .anxious: "Anxious"
    case .low: "Low"
    case .overwhelmed: "Overwhelmed"
    }
  }

  var emoji: String {
    switch self {
    case .bright: "😊"
    case .calm: "🙂"
    case .okay: "😐"
    case .anxious: "😰"
    case .low: "😔"
    case .overwhelmed: "😣"
    }
  }
}
```

Change `CheckInEntry.mood` to `CheckInMood(storedKey: moodKey)`.

- [ ] **Step 4: Implement idempotent version-2 key rewriting**

Set `currentVersion = 2`. After the existing legacy-entry insertion, rewrite only recognized old keys:

```swift
private static let version2MoodMap = [
  "good": "bright",
  "anxious": "anxious",
  "overwhelmed": "overwhelmed",
  "low": "low",
  "frustrated": "overwhelmed",
  "drained": "low",
]

for entry in existingCheckIns {
  if let migrated = version2MoodMap[entry.moodKey] {
    entry.moodKey = migrated
  }
}
```

Update legacy mapping to `radiant -> bright`, `steady -> calm`, `neutral -> okay`, `stressed -> anxious`, and `tired -> low`.

- [ ] **Step 5: Run migration and domain tests**

Run the Step 2 command.

Expected: PASS, including repeated migration and unknown-key behavior.

- [ ] **Step 6: Commit the mood migration**

```bash
git add Sources/Features/CheckIn/CheckInMood.swift \
  Sources/Features/CheckIn/CheckInEntry.swift \
  Sources/Services/CheckInMigrationService.swift \
  Tests/DailyBetterTests/CheckInEntryTests.swift \
  Tests/DailyBetterTests/CheckInMigrationServiceTests.swift
git commit -m "feat: migrate to balanced journal moods"
```

### Task 2: Add create/edit persistence contracts

**Files:**
- Create: `Sources/Features/CheckIn/EntryComposerMode.swift`
- Modify: `Sources/Features/CheckIn/CheckInDraft.swift`
- Modify: `Sources/Features/CheckIn/CheckInRepository.swift`
- Modify: `Sources/Features/CheckIn/CheckInViewModel.swift`
- Modify: `Tests/DailyBetterTests/CheckInRepositoryTests.swift`
- Modify: `Tests/DailyBetterTests/CheckInViewModelTests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `enum EntryComposerMode { case create(createdAt: Date), edit(CheckInEntry) }`
- Produces: `CheckInRepository.update(_:mood:noteText:reflection:) throws`
- Produces: `CheckInRepository.delete(_:) throws`
- Produces: `CheckInViewModel.mode`, `hasUnsavedChanges`, and `committedEntry`

- [ ] **Step 1: Write failing create/edit view-model tests**

Add tests covering these exact outcomes:

```swift
func testCreateModeUsesComposerTimestamp() {
  let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
  let viewModel = makeViewModel(mode: .create(createdAt: timestamp))
  viewModel.selectedMood = .calm

  viewModel.saveWithoutReflection()

  XCTAssertEqual(repository.entries.first?.createdAt, timestamp)
}

func testEditModePreservesIdentityAndTimestampAndClearsStaleReflection() {
  let entry = reflectedEntry(mood: .anxious, note: "Before")
  let viewModel = makeViewModel(mode: .edit(entry))
  viewModel.selectedMood = .calm
  viewModel.noteText = "After"

  viewModel.saveWithoutReflection()

  XCTAssertTrue(viewModel.committedEntry === entry)
  XCTAssertEqual(entry.noteText, "After")
  XCTAssertNil(entry.reflectionText)
  XCTAssertNil(entry.suggestedActionText)
  XCTAssertEqual(entry.reflectionStatus, .none)
}

func testEditCancelDetectionIgnoresUnchangedDraft() {
  let entry = CheckInEntry(mood: .okay, noteText: "Steady")
  let viewModel = makeViewModel(mode: .edit(entry))

  XCTAssertFalse(viewModel.hasUnsavedChanges)
  viewModel.noteText += " now"
  XCTAssertTrue(viewModel.hasUnsavedChanges)
}
```

Add repository tests proving update failure leaves the stored entry unchanged and delete removes exactly one entry.

- [ ] **Step 2: Run the focused tests and verify missing interfaces**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInRepositoryTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Expected: FAIL because edit mode, update, delete, and unsaved-change detection are absent.

- [ ] **Step 3: Add mode and draft snapshots**

```swift
enum EntryComposerMode {
  case create(createdAt: Date)
  case edit(CheckInEntry)

  var createdAt: Date {
    switch self {
    case .create(let createdAt): createdAt
    case .edit(let entry): entry.createdAt
    }
  }
}

struct CheckInDraft: Equatable {
  var mood: CheckInMood?
  var noteText: String
  var createdAt: Date
}
```

Store an `initialDraft` in `CheckInViewModel`; derive `hasUnsavedChanges` by comparing the current normalized draft with that snapshot.

- [ ] **Step 4: Extend the repository without changing reflection providers**

```swift
@MainActor
protocol CheckInRepository: AnyObject {
  func save(_ entry: CheckInEntry) throws
  func update(
    _ entry: CheckInEntry,
    mood: CheckInMood,
    noteText: String?,
    reflection: ReflectionResult?
  ) throws
  func delete(_ entry: CheckInEntry) throws
  func deleteAll() throws
}
```

Implement update in `SwiftDataCheckInRepository` by assigning the new values and saving the context. Snapshot old values first and restore them if save fails. For `reflection == nil`, set reflection strings to nil, source/status to `.none`, and helpfulness to `.unanswered`.

- [ ] **Step 5: Make ViewModel commit create and edit modes**

Use one private method:

```swift
private func persist(
  mood: CheckInMood,
  noteText: String?,
  reflection: ReflectionResult?
) throws -> CheckInEntry {
  switch mode {
  case .create(let createdAt):
    let entry = CheckInEntry(createdAt: createdAt, mood: mood, noteText: noteText)
    apply(reflection, to: entry)
    try repository.save(entry)
    return entry
  case .edit(let entry):
    try repository.update(entry, mood: mood, noteText: noteText, reflection: reflection)
    return entry
  }
}
```

Expose the successful value as `committedEntry`; do not clear the draft before navigation consumes it. Keep all failure paths unchanged and draft-preserving.

- [ ] **Step 6: Regenerate and run tests**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/CheckInRepositoryTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Expected: PASS.

- [ ] **Step 7: Commit persistence contracts**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/CheckIn/EntryComposerMode.swift \
  Sources/Features/CheckIn/CheckInDraft.swift \
  Sources/Features/CheckIn/CheckInRepository.swift \
  Sources/Features/CheckIn/CheckInViewModel.swift \
  Tests/DailyBetterTests/CheckInRepositoryTests.swift \
  Tests/DailyBetterTests/CheckInViewModelTests.swift
git commit -m "feat: support create and edit journal entries"
```

### Task 3: Replace tab navigation with a Timeline presentation coordinator

**Files:**
- Modify: `Sources/App/RootTabView.swift`
- Modify: `Sources/Navigation/AppDestination.swift`
- Delete: `Sources/Navigation/CompactTabBar.swift`
- Modify: `Sources/Services/NotificationRouteStore.swift`
- Modify: `Sources/Services/AppNotificationCoordinator.swift`
- Modify: `Sources/Services/NotificationManager.swift`
- Modify: `Tests/DailyBetterTests/ReminderConfigurationTests.swift`
- Modify: `Tests/DailyBetterUITests/NavigationUITests.swift`
- Modify: `Tests/DailyBetterUITests/SettingsUITests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `enum AppDestination { case newEntry }`
- Produces: `RootPresentation.newEntry(EntryComposerMode)` and `.detail(CheckInEntry)`
- Consumes: `CheckInView(mode:onCancel:onEntryCommitted:)`
- Consumes: `TimelineView(onCheckIn:onSelectEntry:)`

- [ ] **Step 1: Rewrite navigation UI tests to describe Timeline-first launch**

```swift
func testLaunchStartsOnTimelineWithoutTabs() {
  let app = launchApp()

  XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
  XCTAssertTrue(app.buttons["timeline.checkIn"].exists)
  XCTAssertFalse(app.buttons["tab.checkIn"].exists)
  XCTAssertFalse(app.buttons["tab.timeline"].exists)
}

func testCheckInPresentsFullScreenComposerAndCloseReturnsToTimeline() {
  let app = launchApp()
  app.buttons["timeline.checkIn"].tap()

  XCTAssertTrue(app.navigationBars["New Entry"].waitForExistence(timeout: 2))
  app.buttons["checkIn.close"].tap()
  XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
}
```

Update the Settings test to assert no legacy tab identifiers exist before, during, and after Settings navigation.

- [ ] **Step 2: Run navigation tests and verify they fail against the tab root**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/NavigationUITests \
  -only-testing:DailyBetterUITests/SettingsUITests
```

Expected: FAIL because launch still starts on Check In and legacy tab controls exist.

- [ ] **Step 3: Implement a single full-screen presentation enum**

```swift
private enum RootPresentation: Identifiable {
  case newEntry(EntryComposerMode)
  case detail(CheckInEntry)

  var id: String {
    switch self {
    case .newEntry: "new-entry"
    case .detail(let entry): "detail-\(entry.id.uuidString)"
    }
  }
}
```

`RootTabView` owns `@State private var presentation: RootPresentation?` and renders only one `NavigationStack` containing Timeline. Present New Entry and Entry Detail with one `.fullScreenCover(item:)` switch. SwiftUI does not reliably rebuild an active item cover when its enum case changes, so route every composer-to-detail transition through one coordinator helper:

```swift
@MainActor
private func showDetailAfterComposer(_ entry: CheckInEntry) {
  presentation = nil
  Task { @MainActor in
    await Task.yield()
    presentation = .detail(entry)
  }
}
```

Use the same dismiss-then-yield sequence when replacing Detail with Edit. On detail Back, set `presentation` to nil.

- [ ] **Step 4: Collapse notification routing to the composer**

Change `AppDestination` to:

```swift
enum AppDestination: String, Hashable {
  case newEntry
}
```

Map the daily reminder identifier to `.newEntry`. When `NotificationRouteStore.pendingDestination == .newEntry`, Root presents `.newEntry(.create(createdAt: .now))` and clears the pending value.

- [ ] **Step 5: Remove CompactTabBar and regenerate the project**

Delete `Sources/Navigation/CompactTabBar.swift` with `apply_patch`, then run:

```bash
xcodegen generate
```

Expected: project regeneration succeeds and the deleted file is absent from the target.

- [ ] **Step 6: Run navigation and reminder tests**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/ReminderConfigurationTests \
  -only-testing:DailyBetterUITests/NavigationUITests \
  -only-testing:DailyBetterUITests/SettingsUITests
```

Expected: PASS.

- [ ] **Step 7: Commit Timeline-first navigation**

```bash
git add project.yml DailyBetter.xcodeproj Sources/App/RootTabView.swift \
  Sources/Navigation/AppDestination.swift Sources/Navigation/CompactTabBar.swift \
  Sources/Services/NotificationRouteStore.swift \
  Sources/Services/AppNotificationCoordinator.swift \
  Sources/Services/NotificationManager.swift \
  Tests/DailyBetterTests/ReminderConfigurationTests.swift \
  Tests/DailyBetterUITests/NavigationUITests.swift \
  Tests/DailyBetterUITests/SettingsUITests.swift
git commit -m "feat: make timeline the journal home"
```

### Task 4: Build the Timeline home and fixed Check In action

**Files:**
- Modify: `Sources/Features/Timeline/TimelineView.swift`
- Modify: `Sources/Features/Timeline/TimelineEntryRow.swift`
- Modify: `Sources/Design/DailyBetterStyle.swift`
- Modify: `Tests/DailyBetterUITests/TimelineUITests.swift`

**Interfaces:**
- Produces: `TimelineView(refreshToken:onCheckIn:onSelectEntry:)`
- Produces accessibility identifiers: `timeline.checkIn`, `timeline.entry.row`, `timeline.entry.attachment.badge`

- [ ] **Step 1: Add failing UI tests for the root CTA and bounded summaries**

```swift
func testTimelineHasFixedCheckInAction() {
  let app = launchSeededApp()
  let action = app.buttons["timeline.checkIn"]

  XCTAssertTrue(action.waitForExistence(timeout: 5))
  XCTAssertTrue(action.isHittable)
  XCTAssertGreaterThan(action.frame.minY, app.otherElements["timeline.week"].frame.maxY)
}

func testLongTimelineSummaryStaysAtThreeLines() {
  let app = launchLongEntryApp()
  let preview = app.staticTexts["timeline.entry.note.preview"]

  XCTAssertTrue(preview.waitForExistence(timeout: 5))
  XCTAssertLessThanOrEqual(preview.frame.height, 88)
}
```

- [ ] **Step 2: Run Timeline UI tests and verify the CTA test fails**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/TimelineUITests
```

Expected: FAIL because `timeline.checkIn` does not exist.

- [ ] **Step 3: Move detail presentation out and add callbacks**

```swift
struct TimelineView: View {
  let refreshToken: Int
  let onCheckIn: () -> Void
  let onSelectEntry: (CheckInEntry) -> Void
}
```

Replace the row tap assignment with `onSelectEntry(entry)` and remove the local entry sheet.

- [ ] **Step 4: Add the fixed gradient action**

Use `.safeAreaInset(edge: .bottom)` and this style boundary:

```swift
Button(action: onCheckIn) {
  Label("Check in", systemImage: "plus")
    .font(.system(size: 17, weight: .semibold))
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 56)
    .background(DailyBetterStyle.primaryAction, in: Capsule())
}
.accessibilityIdentifier("timeline.checkIn")
```

Add `DailyBetterStyle.primaryAction` as a two-stop muted green `LinearGradient`. Keep the Timeline scroll content padded above the fixed action.

- [ ] **Step 5: Verify Timeline behavior**

Run the Step 2 command.

Expected: PASS; the week strip remains reachable and long notes remain bounded.

- [ ] **Step 6: Commit Timeline home UI**

```bash
git add Sources/Features/Timeline/TimelineView.swift \
  Sources/Features/Timeline/TimelineEntryRow.swift \
  Sources/Design/DailyBetterStyle.swift \
  Tests/DailyBetterUITests/TimelineUITests.swift
git commit -m "feat: add timeline journal entry point"
```

### Task 5: Replace Check In with a full-screen, keyboard-safe composer

**Files:**
- Modify: `Sources/Features/CheckIn/CheckInView.swift`
- Modify: `Sources/Features/CheckIn/MoodSelector.swift`
- Modify: `Tests/DailyBetterUITests/CheckInFlowUITests.swift`

**Interfaces:**
- Produces: `CheckInView(mode:remoteProvider:onCancel:onEntryCommitted:)`
- Produces identifiers: `checkIn.close`, `checkIn.timestamp`, `checkIn.save`, `checkIn.reflect`
- Consumes: `EntryComposerMode` and `CheckInViewModel.hasUnsavedChanges`

- [ ] **Step 1: Add failing composer layout and discard tests**

```swift
func testLongTextKeepsFixedActionsVisibleAboveKeyboard() {
  let app = launchComposer()
  app.buttons["mood.calm"].tap()
  app.textViews["checkIn.note"].tap()
  app.textViews["checkIn.note"].typeText(String(repeating: "A long thought. ", count: 80))

  XCTAssertTrue(app.buttons["checkIn.save"].isHittable)
  XCTAssertTrue(app.buttons["checkIn.reflect"].isHittable)
  XCTAssertGreaterThan(app.buttons["checkIn.save"].frame.minY, app.keyboards.firstMatch.frame.minY - 120)
  XCTAssertFalse(app.buttons["checkIn.dismissKeyboard"].exists)
}

func testClosingChangedDraftRequiresDiscardConfirmation() {
  let app = launchComposer()
  app.buttons["mood.bright"].tap()
  app.buttons["checkIn.close"].tap()

  XCTAssertTrue(app.alerts["Discard this entry?"].waitForExistence(timeout: 2))
}
```

- [ ] **Step 2: Run Check In UI tests and verify they fail**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/CheckInFlowUITests
```

Expected: FAIL because the approved identifiers, mood keys, fixed two-button dock, and discard alert are absent.

- [ ] **Step 3: Rebuild the screen around fixed top and bottom regions**

Use a `ScrollView` for mood and editor content, a top toolbar for close/timestamp, and one bottom inset:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
  HStack(spacing: 12) {
    composerButton("Save", identifier: "checkIn.save", primary: false) {
      viewModel.saveWithoutReflection()
    }
    composerButton("Reflect", identifier: "checkIn.reflect", primary: true) {
      Task { await viewModel.reflect() }
    }
  }
  .padding(16)
  .background(.ultraThinMaterial)
}
```

Do not conditionally hide the dock when the editor is focused. Remove the keyboard toolbar entirely. Use `.scrollDismissesKeyboard(.interactively)` and enough bottom content padding to avoid overlap.

- [ ] **Step 4: Add close and discard behavior**

Close immediately when `hasUnsavedChanges == false`. Otherwise present:

```swift
.confirmationDialog("Discard this entry?", isPresented: $confirmsDiscard) {
  Button("Discard entry", role: .destructive, action: onCancel)
  Button("Keep writing", role: .cancel) {}
} message: {
  Text("Your mood and writing have not been saved.")
}
```

Display `mode.createdAt.formatted(date: .abbreviated, time: .shortened)` with identifier `checkIn.timestamp`.

- [ ] **Step 5: Update mood visuals and accessibility**

Render six items using the approved order. Keep each label visible, combine emoji plus label for VoiceOver, use `.isSelected`, and assign `mood.<rawValue>` identifiers. Use SF Pro Semibold for action labels rather than rounded bold.

- [ ] **Step 6: Preserve the three-way failure action**

Keep the existing alert title and draft preservation, but expose exactly:

```swift
Button("Try again") { Task { await viewModel.reflect() } }
Button("Save without reflection") { viewModel.saveWithoutReflection() }
Button("Cancel", role: .cancel) { viewModel.failure = nil }
```

- [ ] **Step 7: Run Check In tests**

Run the Step 2 command.

Expected: PASS at normal and accessibility text sizes; Save and Reflect remain hittable with the keyboard open.

- [ ] **Step 8: Commit the composer**

```bash
git add Sources/Features/CheckIn/CheckInView.swift \
  Sources/Features/CheckIn/MoodSelector.swift \
  Tests/DailyBetterUITests/CheckInFlowUITests.swift
git commit -m "feat: add full-screen journal composer"
```

### Task 6: Complete saved detail, edit, and delete flows

**Files:**
- Modify: `Sources/Features/Timeline/EntryDetailView.swift`
- Modify: `Sources/Features/CheckIn/ReflectionView.swift`
- Modify: `Sources/App/RootTabView.swift`
- Modify: `Tests/DailyBetterUITests/TimelineUITests.swift`
- Modify: `Tests/DailyBetterUITests/CheckInFlowUITests.swift`

**Interfaces:**
- Produces: `EntryDetailView(entry:onBack:onEdit:onDelete:)`
- Consumes: `RootPresentation.newEntry(.edit(entry))`
- Consumes: `CheckInRepository.delete(_:)`

- [ ] **Step 1: Add failing detail transition and edit tests**

```swift
func testSaveOpensDetailAndBackReturnsToTimeline() {
  let app = launchComposer()
  app.buttons["mood.calm"].tap()
  app.buttons["checkIn.save"].tap()

  XCTAssertTrue(app.navigationBars["Entry"].waitForExistence(timeout: 3))
  app.buttons["entry.back"].tap()
  XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 2))
}

func testEditingNoteClearsStaleReflectionAndUpdatesSameEntry() {
  let app = launchReflectedEntryDetail()
  app.buttons["entry.menu"].tap()
  app.buttons["Edit entry"].tap()
  let note = app.textViews["checkIn.note"]
  note.tap()
  note.typeText(" Updated")
  app.buttons["checkIn.save"].tap()

  XCTAssertTrue(app.staticTexts["Before Updated"].waitForExistence(timeout: 3))
  XCTAssertFalse(app.staticTexts["reflection.title"].exists)
}
```

Add a delete test that confirms, returns to Timeline, and removes the selected row.

- [ ] **Step 2: Run detail flow tests and verify missing actions**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/TimelineUITests \
  -only-testing:DailyBetterUITests/CheckInFlowUITests
```

Expected: FAIL because detail is still a Timeline-owned sheet and has no edit/delete menu.

- [ ] **Step 3: Convert detail to callback-driven full-screen content**

```swift
struct EntryDetailView: View {
  @Bindable var entry: CheckInEntry
  let onBack: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
}
```

Set title to `Entry`, identifier the Back button `entry.back`, and add `entry.menu` with only `Edit entry` and destructive `Delete entry`. Require a destructive confirmation before invoking `onDelete`.

- [ ] **Step 4: Avoid empty reflection chrome**

Render `ReflectionView` only when normalized reflection or suggested-action content exists. Keep helpfulness controls inside the same conditional. Rename detail-specific accessibility identifiers from `reflection.originalNote` to `entry.note.full` while retaining reflection identifiers for saved AI content.

- [ ] **Step 5: Wire Root presentation replacement**

On edit, dismiss `.detail(entry)`, yield once on `MainActor`, and present `.newEntry(.edit(entry))`. On commit, call `showDetailAfterComposer(_:)`. On delete, call the repository, dismiss detail, increment Timeline's refresh token, and keep the selected date aligned with the deleted entry's date. Add a UI assertion that each transition displays exactly one full-screen page and never briefly exposes the legacy root tab controls.

- [ ] **Step 6: Run detail and Check In tests**

Run the Step 2 command.

Expected: PASS for Save, Reflect, Back, Edit, Cancel, and Delete paths.

- [ ] **Step 7: Commit complete detail flow**

```bash
git add Sources/Features/Timeline/EntryDetailView.swift \
  Sources/Features/CheckIn/ReflectionView.swift \
  Sources/App/RootTabView.swift \
  Tests/DailyBetterUITests/TimelineUITests.swift \
  Tests/DailyBetterUITests/CheckInFlowUITests.swift
git commit -m "feat: complete journal detail workflow"
```

### Task 7: Run core regression and upgrade checks

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Test: `Tests/DailyBetterTests/ProjectSmokeTests.swift`
- Test: `Tests/DailyBetterUITests/LaunchSmokeUITests.swift`

**Interfaces:**
- Validates all interfaces produced by Tasks 1-6.

- [ ] **Step 1: Update product and testing documentation**

Update README navigation copy to say Timeline is home and Check In is a full-screen action. Add an `Unreleased` CHANGELOG entry listing Timeline-first navigation, balanced moods, full-screen composer, and editable detail.

- [ ] **Step 2: Run all unit tests**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Run the critical UI suites**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/LaunchSmokeUITests \
  -only-testing:DailyBetterUITests/NavigationUITests \
  -only-testing:DailyBetterUITests/TimelineUITests \
  -only-testing:DailyBetterUITests/CheckInFlowUITests \
  -only-testing:DailyBetterUITests/SettingsUITests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Build for a generic iOS device**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter \
  -configuration Debug -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Perform the production-like migration check**

Install a build using a store seeded with version-1 keys, launch once, and verify:

```text
good -> Bright
frustrated -> Overwhelmed
drained -> Low
existing note/reflection/timestamp unchanged
second launch creates no duplicate entries
```

- [ ] **Step 6: Commit documentation after all checks pass**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document timeline-first journal flow"
```
