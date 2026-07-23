# Daily Better Local Emotional Journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the released affirmation dashboard with a tested, on-device Check In and Timeline experience that preserves existing mood data, supports one local reminder, and exposes a provider-independent reflection boundary without sending journal text to a live AI service.

**Architecture:** Build the local journal as a vertical feature slice around a new SwiftData `CheckInEntry` model. Keep legacy models in the schema for a non-destructive migration, route persistence through focused repository and migration types, and inject reflection/reminder services behind protocols so UI behavior can be tested without network or notification side effects. Use XcodeGen as the project source of truth and add XCTest/UI test targets before changing product behavior.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, UserNotifications, XCTest, XCUITest, XcodeGen 2.45+, iOS 17+

---

## Execution Preconditions

- Execute this plan in a clean worktree created from the commit containing this plan. Do not copy the uncommitted three-reminder work from `codex/feature-daily-reminders` into the implementation branch.
- Use `superpowers:using-git-worktrees` before Task 1.
- Resolve the current `CoreSimulator is out of date (1051.54.0 vs 1051.55.0)` error before the first test command.
- Verify the simulator environment with:

```bash
xcrun simctl list devices available
```

Expected: an available `iPhone 16 Pro` simulator and no `DVTCoreSimulatorAdditionsErrorDomain` error.

- Regenerate `DailyBetter.xcodeproj` from `project.yml` whenever project sources or targets change. Never make a project-only edit that is absent from `project.yml`.

## File Map

### Project and Tests

- Modify `project.yml`: signing source of truth, test targets, and shared scheme.
- Create `Tests/DailyBetterTests/`: domain, migration, calendar, repository, reflection, reminder, and export tests.
- Create `Tests/DailyBetterUITests/`: critical user-flow UI tests.

### Check In and Reflection

- Create `Sources/Features/CheckIn/CheckInMood.swift`: six non-clinical mood values.
- Create `Sources/Features/CheckIn/CheckInEntry.swift`: persisted journal model.
- Create `Sources/Features/CheckIn/CheckInDraft.swift`: non-persisted composer state.
- Create `Sources/Features/CheckIn/CheckInRepository.swift`: persistence boundary.
- Create `Sources/Features/CheckIn/CheckInViewModel.swift`: composer orchestration.
- Create `Sources/Features/CheckIn/CheckInView.swift`: mood and text UI.
- Create `Sources/Features/CheckIn/MoodSelector.swift`: accessible mood control.
- Create `Sources/Features/CheckIn/ReflectionView.swift`: saved reflection UI.
- Create `Sources/Features/Reflection/ReflectionTypes.swift`: reflection domain types.
- Create `Sources/Features/Reflection/ReflectionProviding.swift`: provider protocol.
- Create `Sources/Features/Reflection/LocalReflectionProvider.swift`: mood-only responses.
- Create `Sources/Features/Reflection/UnavailableRemoteReflectionProvider.swift`: explicit pre-AI failure.

### Timeline, Design, and Navigation

- Create `Sources/Features/Timeline/TimelineCalendar.swift`: week calculations.
- Create `Sources/Features/Timeline/TimelineView.swift`: week strip and entries.
- Create `Sources/Features/Timeline/TimelineEntryRow.swift`: chronological row.
- Create `Sources/Features/Timeline/EntryDetailView.swift`: saved detail.
- Create `Sources/Design/DailyBetterStyle.swift`: fixed style tokens.
- Create `Sources/Design/DailyBetterBackground.swift`: gradient and grain.
- Create `Sources/Navigation/AppDestination.swift`: two destinations.
- Create `Sources/Navigation/CompactTabBar.swift`: consistent two-tab control.
- Modify `Sources/App/RootTabView.swift`: app shell.

### Migration, Reminder, Settings, and Data Control

- Create `Sources/Services/CheckInMigrationService.swift`: legacy mood migration.
- Modify `Sources/Models/AppPreferences.swift`: migration and consent state.
- Modify `Sources/Services/AppBootstrapper.swift`: bootstrap new model.
- Modify `Sources/App/DailyBetterApp.swift`: model registration.
- Replace `Sources/Services/NotificationManager.swift`: one local reminder.
- Replace `Sources/Views/Settings/SettingsView.swift`: approved settings structure.
- Create `Sources/Services/TimelineExportService.swift`: user-readable export.

## Task 1: Establish Generated Test Targets

**Files:**
- Modify: `project.yml`
- Create: `Tests/DailyBetterTests/ProjectSmokeTests.swift`
- Create: `Tests/DailyBetterUITests/LaunchSmokeUITests.swift`
- Regenerate: `DailyBetter.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add unit and UI test targets to `project.yml`**

Replace the empty development team and append test targets and a scheme:

```yaml
settings:
  base:
    SWIFT_VERSION: 5.0
    MARKETING_VERSION: 1.0.0
    CURRENT_PROJECT_VERSION: 1
    IPHONEOS_DEPLOYMENT_TARGET: 17.0
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: 6UYTZXY3H9
    TARGETED_DEVICE_FAMILY: "1,2"

targets:
  DailyBetter:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Sources
    resources:
      - Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.guoxl.DailyBetter
        PRODUCT_NAME: DailyBetter
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Daily Better
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.healthcare-fitness
        INFOPLIST_KEY_NSUserNotificationUsageDescription: Daily Better can send one optional daily reminder at the time you choose.
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        DEVELOPMENT_ASSET_PATHS: Resources/PreviewContent/Preview Assets.xcassets

  DailyBetterTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Tests/DailyBetterTests
    dependencies:
      - target: DailyBetter
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES

  DailyBetterUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - Tests/DailyBetterUITests
    dependencies:
      - target: DailyBetter
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES

schemes:
  DailyBetter:
    build:
      targets:
        DailyBetter: all
        DailyBetterTests: [test]
        DailyBetterUITests: [test]
    test:
      gatherCoverageData: true
      targets:
        - name: DailyBetterTests
        - name: DailyBetterUITests
```

- [ ] **Step 2: Create the unit-test smoke file**

```swift
import XCTest
@testable import DailyBetter

final class ProjectSmokeTests: XCTestCase {
  func testTestTargetRuns() {
    XCTAssertTrue(true)
  }
}
```

- [ ] **Step 3: Create the UI-test smoke file**

```swift
import XCTest

final class LaunchSmokeUITests: XCTestCase {
  func testAppLaunches() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing"]
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
  }
}
```

- [ ] **Step 4: Generate the project and run smoke tests**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Expected: `Generated project` followed by `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit the testing foundation**

```bash
git add project.yml DailyBetter.xcodeproj Tests
git commit -m "test: add generated iOS test targets"
```

## Task 2: Add the Check-In Domain Model

**Files:**
- Create: `Sources/Features/CheckIn/CheckInMood.swift`
- Create: `Sources/Features/CheckIn/CheckInEntry.swift`
- Create: `Sources/Features/Reflection/ReflectionTypes.swift`
- Test: `Tests/DailyBetterTests/CheckInEntryTests.swift`

- [ ] **Step 1: Write failing domain tests**

```swift
import XCTest
@testable import DailyBetter

final class CheckInEntryTests: XCTestCase {
  func testAllMoodsHaveStableLabelsAndEmoji() {
    XCTAssertEqual(CheckInMood.allCases.map(\.rawValue), [
      "anxious", "overwhelmed", "low", "frustrated", "drained", "good"
    ])
    XCTAssertEqual(CheckInMood.overwhelmed.emoji, "😣")
    XCTAssertEqual(CheckInMood.good.title, "Good")
  }

  func testEntryExposesPersistedEnumValues() {
    let entry = CheckInEntry(
      mood: .frustrated,
      noteText: "The meeting kept going in circles.",
      reflectionSource: .ai,
      reflectionStatus: .completed,
      helpfulness: .better
    )
    XCTAssertEqual(entry.mood, .frustrated)
    XCTAssertEqual(entry.reflectionSource, .ai)
    XCTAssertEqual(entry.reflectionStatus, .completed)
    XCTAssertEqual(entry.helpfulness, .better)
  }
}
```

- [ ] **Step 2: Run the tests to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInEntryTests test
```

Expected: FAIL because `CheckInMood` and `CheckInEntry` do not exist.

- [ ] **Step 3: Implement `CheckInMood`**

```swift
import Foundation

enum CheckInMood: String, CaseIterable, Codable, Identifiable {
  case anxious
  case overwhelmed
  case low
  case frustrated
  case drained
  case good

  var id: String { rawValue }
  var title: String { rawValue.capitalized }

  var emoji: String {
    switch self {
    case .anxious: "😰"
    case .overwhelmed: "😣"
    case .low: "😔"
    case .frustrated: "😤"
    case .drained: "😴"
    case .good: "😊"
    }
  }
}
```

- [ ] **Step 4: Implement reflection persistence types**

```swift
import Foundation

enum ReflectionSource: String, Codable { case local, ai, none }
enum ReflectionStatus: String, Codable { case none, pending, completed, failed, safetyRouted }
enum Helpfulness: String, Codable { case better, unchanged, unanswered }

struct ReflectionRequest: Equatable, Sendable {
  let mood: CheckInMood
  let noteText: String
  let localeIdentifier: String
  let requestID: UUID
}

struct ReflectionResult: Equatable, Sendable {
  let reflectionText: String
  let suggestedActionText: String
  let source: ReflectionSource
}

enum ReflectionError: Error, Equatable {
  case unavailable
  case invalidResponse
  case safetyRouted
}
```

- [ ] **Step 5: Implement `CheckInEntry`**

```swift
import Foundation
import SwiftData

@Model
final class CheckInEntry {
  var id: UUID
  var createdAt: Date
  var moodKey: String
  var noteText: String?
  var reflectionText: String?
  var suggestedActionText: String?
  var reflectionSourceKey: String
  var reflectionStatusKey: String
  var helpfulnessKey: String
  var safetyRouteShown: Bool
  var legacyMoodEntryID: UUID?

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    mood: CheckInMood,
    noteText: String? = nil,
    reflectionText: String? = nil,
    suggestedActionText: String? = nil,
    reflectionSource: ReflectionSource = .none,
    reflectionStatus: ReflectionStatus = .none,
    helpfulness: Helpfulness = .unanswered,
    safetyRouteShown: Bool = false,
    legacyMoodEntryID: UUID? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.moodKey = mood.rawValue
    self.noteText = noteText
    self.reflectionText = reflectionText
    self.suggestedActionText = suggestedActionText
    self.reflectionSourceKey = reflectionSource.rawValue
    self.reflectionStatusKey = reflectionStatus.rawValue
    self.helpfulnessKey = helpfulness.rawValue
    self.safetyRouteShown = safetyRouteShown
    self.legacyMoodEntryID = legacyMoodEntryID
  }

  var mood: CheckInMood { CheckInMood(rawValue: moodKey) ?? .good }
  var reflectionSource: ReflectionSource { ReflectionSource(rawValue: reflectionSourceKey) ?? .none }
  var reflectionStatus: ReflectionStatus { ReflectionStatus(rawValue: reflectionStatusKey) ?? .none }
  var helpfulness: Helpfulness {
    get { Helpfulness(rawValue: helpfulnessKey) ?? .unanswered }
    set { helpfulnessKey = newValue.rawValue }
  }
}
```

- [ ] **Step 6: Regenerate, run tests, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInEntryTests test
git add Sources/Features Tests/DailyBetterTests/CheckInEntryTests.swift DailyBetter.xcodeproj
git commit -m "feat: add emotional check-in model"
```

Expected: test succeeds before the commit.

## Task 3: Migrate Legacy Mood Data Without Deletion

**Files:**
- Create: `Sources/Services/CheckInMigrationService.swift`
- Modify: `Sources/Models/AppPreferences.swift`
- Modify: `Sources/Services/AppBootstrapper.swift`
- Modify: `Sources/App/DailyBetterApp.swift`
- Test: `Tests/DailyBetterTests/CheckInMigrationServiceTests.swift`

- [ ] **Step 1: Write a failing idempotent migration test**

```swift
import SwiftData
import XCTest
@testable import DailyBetter

@MainActor
final class CheckInMigrationServiceTests: XCTestCase {
  func testMigratesLegacyMoodsOnce() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: Affirmation.self,
      MoodEntry.self,
      CheckInEntry.self,
      AppPreferences.self,
      configurations: configuration
    )
    let context = container.mainContext
    let legacy = MoodEntry(date: Date(timeIntervalSince1970: 1_700_000_000), mood: .stressed)
    let preferences = AppPreferences()
    context.insert(legacy)
    context.insert(preferences)
    try context.save()

    try CheckInMigrationService.runIfNeeded(in: context)
    try CheckInMigrationService.runIfNeeded(in: context)

    let entries = try context.fetch(FetchDescriptor<CheckInEntry>())
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.mood, .overwhelmed)
    XCTAssertEqual(entries.first?.legacyMoodEntryID, legacy.id)
    XCTAssertEqual(preferences.migrationVersion, 1)
  }
}
```

- [ ] **Step 2: Run the test to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInMigrationServiceTests test
```

Expected: FAIL because migration fields and service do not exist.

- [ ] **Step 3: Add migration and consent properties to `AppPreferences`**

Add stored properties with defaults:

```swift
var migrationVersion: Int = 0
var aiConsentVersion: Int = 0
var aiConsentAcceptedAt: Date?
```

Set the same values in `init`:

```swift
self.migrationVersion = 0
self.aiConsentVersion = 0
self.aiConsentAcceptedAt = nil
```

- [ ] **Step 4: Implement the migration service**

```swift
import Foundation
import SwiftData

enum CheckInMigrationService {
  static let currentVersion = 1

  @MainActor
  static func runIfNeeded(in context: ModelContext) throws {
    var descriptor = FetchDescriptor<AppPreferences>()
    descriptor.fetchLimit = 1
    let preferences: AppPreferences
    if let existing = try context.fetch(descriptor).first {
      preferences = existing
    } else {
      let created = AppPreferences()
      context.insert(created)
      preferences = created
    }
    guard preferences.migrationVersion < currentVersion else { return }

    let legacyEntries = try context.fetch(FetchDescriptor<MoodEntry>())
    let existing = try context.fetch(FetchDescriptor<CheckInEntry>())
    let migratedIDs = Set(existing.compactMap(\.legacyMoodEntryID))
    for legacy in legacyEntries where !migratedIDs.contains(legacy.id) {
      context.insert(
        CheckInEntry(
          createdAt: legacy.date,
          mood: map(legacy.moodKind),
          reflectionSource: .none,
          legacyMoodEntryID: legacy.id
        )
      )
    }
    preferences.migrationVersion = currentVersion
    try context.save()
  }

  static func map(_ mood: MoodKind) -> CheckInMood {
    switch mood {
    case .radiant, .steady, .neutral: .good
    case .low: .low
    case .stressed: .overwhelmed
    case .tired: .drained
    }
  }
}
```

- [ ] **Step 5: Register `CheckInEntry` and simplify bootstrap**

Update `DailyBetterApp`:

```swift
.modelContainer(for: [Affirmation.self, MoodEntry.self, CheckInEntry.self, AppPreferences.self])
```

Replace `AppBootstrapper.bootstrapIfNeeded` so new installs no longer seed affirmations and UI tests have deterministic reset/seed paths:

```swift
@MainActor
static func bootstrapIfNeeded(in context: ModelContext) {
  let arguments = ProcessInfo.processInfo.arguments

  if arguments.contains("-ui-testing"), arguments.contains("-reset-store") {
    for entry in (try? context.fetch(FetchDescriptor<CheckInEntry>())) ?? [] { context.delete(entry) }
    for entry in (try? context.fetch(FetchDescriptor<MoodEntry>())) ?? [] { context.delete(entry) }
    for preference in (try? context.fetch(FetchDescriptor<AppPreferences>())) ?? [] { context.delete(preference) }
    try? context.save()
  }

  var descriptor = FetchDescriptor<AppPreferences>()
  descriptor.fetchLimit = 1
  if (try? context.fetch(descriptor).isEmpty) != false {
    context.insert(AppPreferences())
  }
  try? context.save()
  try? CheckInMigrationService.runIfNeeded(in: context)

  if arguments.contains("-ui-testing"), arguments.contains("-seed-check-ins") {
    var entryDescriptor = FetchDescriptor<CheckInEntry>()
    entryDescriptor.fetchLimit = 1
    if (try? context.fetch(entryDescriptor).isEmpty) != false {
      context.insert(
        CheckInEntry(
          createdAt: .now,
          mood: .overwhelmed,
          noteText: "Everything piled up today.",
          reflectionSource: .none
        )
      )
      try? context.save()
    }
  }
}
```

- [ ] **Step 6: Regenerate, run tests, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInMigrationServiceTests test
git add Sources/App/DailyBetterApp.swift Sources/Models/AppPreferences.swift Sources/Services/AppBootstrapper.swift Sources/Services/CheckInMigrationService.swift Tests/DailyBetterTests/CheckInMigrationServiceTests.swift DailyBetter.xcodeproj
git commit -m "feat: migrate legacy moods to check-ins"
```

Expected: test succeeds and legacy `MoodEntry` records remain stored.

## Task 4: Add Reflection Boundaries and Local Responses

**Files:**
- Create: `Sources/Features/Reflection/ReflectionProviding.swift`
- Create: `Sources/Features/Reflection/LocalReflectionProvider.swift`
- Create: `Sources/Features/Reflection/UnavailableRemoteReflectionProvider.swift`
- Test: `Tests/DailyBetterTests/LocalReflectionProviderTests.swift`

- [ ] **Step 1: Write failing provider tests**

```swift
import XCTest
@testable import DailyBetter

final class LocalReflectionProviderTests: XCTestCase {
  func testMoodOnlyReflectionReturnsLocalContent() async throws {
    let result = try await LocalReflectionProvider().reflect(
      ReflectionRequest(mood: .drained, noteText: "", localeIdentifier: "en_US", requestID: UUID())
    )
    XCTAssertEqual(result.source, .local)
    XCTAssertFalse(result.reflectionText.isEmpty)
    XCTAssertFalse(result.suggestedActionText.isEmpty)
  }

  func testUnavailableProviderFailsExplicitly() async {
    do {
      _ = try await UnavailableRemoteReflectionProvider().reflect(
        ReflectionRequest(mood: .anxious, noteText: "A written entry", localeIdentifier: "en_US", requestID: UUID())
      )
      XCTFail("Expected unavailable error")
    } catch {
      XCTAssertEqual(error as? ReflectionError, .unavailable)
    }
  }
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/LocalReflectionProviderTests test
```

Expected: FAIL because providers do not exist.

- [ ] **Step 3: Implement the provider protocol**

```swift
protocol ReflectionProviding: Sendable {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult
}
```

- [ ] **Step 4: Implement deterministic mood-only content**

```swift
struct LocalReflectionProvider: ReflectionProviding {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    let content: (String, String) = switch request.mood {
    case .anxious:
      ("Your mind is looking ahead for what might go wrong. You only need to meet the next moment.", "Name one thing you can control in the next five minutes.")
    case .overwhelmed:
      ("Several things may be asking for your attention at once. You do not need to solve the whole day now.", "Choose the task with the nearest real consequence and give it five minutes.")
    case .low:
      ("This moment feels heavy. You are allowed to lower the demands you place on yourself.", "Do one caring thing for your body: water, food, fresh air, or rest.")
    case .frustrated:
      ("Something is pushing against what you expected or needed. A pause can keep frustration from choosing the next move.", "Relax your jaw and shoulders, then write the outcome you actually need.")
    case .drained:
      ("Your energy is limited right now. A smaller version of the day still counts.", "Reduce the next task until it can be started in two minutes.")
    case .good:
      ("Something feels good enough to notice. Let this moment be real without turning it into another task.", "Name one detail you want to remember from this moment.")
    }
    return ReflectionResult(reflectionText: content.0, suggestedActionText: content.1, source: .local)
  }
}
```

- [ ] **Step 5: Implement explicit pre-AI failure**

```swift
struct UnavailableRemoteReflectionProvider: ReflectionProviding {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    throw ReflectionError.unavailable
  }
}
```

- [ ] **Step 6: Regenerate, test, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/LocalReflectionProviderTests test
git add Sources/Features/Reflection Tests/DailyBetterTests/LocalReflectionProviderTests.swift DailyBetter.xcodeproj
git commit -m "feat: add reflection service boundary"
```

Expected: provider tests pass before the commit.

## Task 5: Add Repository and Draft-Preserving View Model

**Files:**
- Create: `Sources/Features/CheckIn/CheckInDraft.swift`
- Create: `Sources/Features/CheckIn/CheckInRepository.swift`
- Create: `Sources/Features/CheckIn/CheckInViewModel.swift`
- Test: `Tests/DailyBetterTests/CheckInViewModelTests.swift`

- [ ] **Step 1: Write failing orchestration tests**

```swift
import XCTest
@testable import DailyBetter

@MainActor
final class CheckInViewModelTests: XCTestCase {
  func testSaveOnlyPersistsWithoutCallingProvider() async {
    let repository = InMemoryCheckInRepository()
    let provider = SpyReflectionProvider(result: .failure(.unavailable))
    let model = CheckInViewModel(repository: repository, remoteProvider: provider)
    model.selectedMood = .good
    model.noteText = "The presentation went well."

    await model.saveWithoutReflection()

    XCTAssertEqual(repository.entries.count, 1)
    let providerCallCount = await provider.callCount
    XCTAssertEqual(providerCallCount, 0)
    XCTAssertEqual(model.noteText, "")
  }

  func testRemoteFailurePreservesDraft() async {
    let repository = InMemoryCheckInRepository()
    let provider = SpyReflectionProvider(result: .failure(.unavailable))
    let model = CheckInViewModel(repository: repository, remoteProvider: provider)
    model.selectedMood = .overwhelmed
    model.noteText = "Everything piled up."

    await model.reflect()

    XCTAssertEqual(model.noteText, "Everything piled up.")
    XCTAssertEqual(model.failure, .unavailable)
    XCTAssertTrue(repository.entries.isEmpty)
  }
}

@MainActor
final class InMemoryCheckInRepository: CheckInRepository {
  var entries: [CheckInEntry] = []
  func save(_ entry: CheckInEntry) throws { entries.append(entry) }
  func deleteAll() throws { entries.removeAll() }
}

actor SpyReflectionProvider: ReflectionProviding {
  private(set) var callCount = 0
  let result: Result<ReflectionResult, ReflectionError>
  init(result: Result<ReflectionResult, ReflectionError>) { self.result = result }
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    callCount += 1
    return try result.get()
  }
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInViewModelTests test
```

Expected: FAIL because draft, repository, and view model types do not exist.

- [ ] **Step 3: Implement draft and repository**

```swift
import Foundation

struct CheckInDraft: Equatable {
  var mood: CheckInMood?
  var noteText = ""
  var trimmedNote: String { noteText.trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

```swift
import SwiftData

@MainActor
protocol CheckInRepository: AnyObject {
  func save(_ entry: CheckInEntry) throws
  func deleteAll() throws
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepository {
  private let context: ModelContext
  init(context: ModelContext) { self.context = context }
  func save(_ entry: CheckInEntry) throws { context.insert(entry); try context.save() }
  func deleteAll() throws { try context.delete(model: CheckInEntry.self); try context.save() }
}
```

- [ ] **Step 4: Implement `CheckInViewModel`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class CheckInViewModel {
  private let repository: CheckInRepository
  private let localProvider: any ReflectionProviding
  private let remoteProvider: any ReflectionProviding

  var selectedMood: CheckInMood?
  var noteText = ""
  var presentedEntry: CheckInEntry?
  var failure: ReflectionError?
  var isReflecting = false

  init(
    repository: CheckInRepository,
    localProvider: any ReflectionProviding = LocalReflectionProvider(),
    remoteProvider: any ReflectionProviding
  ) {
    self.repository = repository
    self.localProvider = localProvider
    self.remoteProvider = remoteProvider
  }

  func saveWithoutReflection() async {
    guard let mood = selectedMood else { return }
    do {
      try repository.save(CheckInEntry(mood: mood, noteText: normalizedNote))
      resetDraft()
    } catch {
      failure = .unavailable
    }
  }

  func reflect() async {
    guard let mood = selectedMood else { return }
    failure = nil
    isReflecting = true
    defer { isReflecting = false }
    let note = normalizedNote ?? ""
    let provider = note.isEmpty ? localProvider : remoteProvider
    let request = ReflectionRequest(
      mood: mood,
      noteText: note,
      localeIdentifier: Locale.current.identifier,
      requestID: UUID()
    )
    do {
      let result = try await provider.reflect(request)
      let entry = CheckInEntry(
        mood: mood,
        noteText: note.isEmpty ? nil : note,
        reflectionText: result.reflectionText,
        suggestedActionText: result.suggestedActionText,
        reflectionSource: result.source,
        reflectionStatus: .completed
      )
      try repository.save(entry)
      presentedEntry = entry
      resetDraft()
    } catch let error as ReflectionError {
      failure = error
    } catch {
      failure = .unavailable
    }
  }

  private var normalizedNote: String? {
    let value = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private func resetDraft() {
    selectedMood = nil
    noteText = ""
  }
}
```

- [ ] **Step 5: Regenerate, test, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/CheckInViewModelTests test
git add Sources/Features/CheckIn Tests/DailyBetterTests/CheckInViewModelTests.swift DailyBetter.xcodeproj
git commit -m "feat: orchestrate local check-ins"
```

Expected: view-model tests pass before the commit.

## Task 6: Build the Fixed Visual System and Two-Tab Shell

**Files:**
- Create: `Sources/Design/DailyBetterStyle.swift`
- Create: `Sources/Design/DailyBetterBackground.swift`
- Create: `Sources/Navigation/AppDestination.swift`
- Create: `Sources/Navigation/CompactTabBar.swift`
- Modify: `Sources/App/RootTabView.swift`
- Test: `Tests/DailyBetterUITests/NavigationUITests.swift`

- [ ] **Step 1: Write a failing navigation UI test**

```swift
import XCTest

final class NavigationUITests: XCTestCase {
  func testRootHasOnlyCheckInAndTimelineDestinations() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    XCTAssertTrue(app.buttons["tab.checkIn"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["tab.timeline"].exists)
    XCTAssertFalse(app.buttons["tab.library"].exists)
    XCTAssertFalse(app.buttons["tab.settings"].exists)
  }
}
```

- [ ] **Step 2: Run the UI test to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterUITests/NavigationUITests test
```

Expected: FAIL because the released app exposes four tabs.

- [ ] **Step 3: Implement fixed style tokens**

```swift
import SwiftUI

enum DailyBetterStyle {
  static let ink = Color(red: 0.09, green: 0.13, blue: 0.11)
  static let muted = Color(red: 0.39, green: 0.45, blue: 0.41)
  static let tint = Color(red: 0.17, green: 0.46, blue: 0.35)
  static let darkAction = Color(red: 0.12, green: 0.17, blue: 0.14)
  static let top = Color(red: 0.98, green: 0.99, blue: 0.98)
  static let bottom = Color(red: 0.93, green: 0.96, blue: 0.94)
  static let glass = Color.white.opacity(0.60)
  static let hairline = Color(red: 0.24, green: 0.37, blue: 0.29).opacity(0.13)
}
```

- [ ] **Step 4: Implement gradient and deterministic grain**

```swift
import SwiftUI

struct DailyBetterBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [DailyBetterStyle.top, DailyBetterStyle.bottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [Color(red: 0.74, green: 0.88, blue: 0.81).opacity(0.55), .clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 260
      )
      Canvas { context, size in
        var dots = Path()
        for x in stride(from: 4.0, through: size.width, by: 8.0) {
          for y in stride(from: 4.0, through: size.height, by: 8.0) {
            dots.addEllipse(in: CGRect(x: x, y: y, width: 0.8, height: 0.8))
          }
        }
        context.fill(dots, with: .color(DailyBetterStyle.tint.opacity(0.06)))
      }
      .allowsHitTesting(false)
    }
    .ignoresSafeArea()
  }
}

extension View {
  func dailyBetterBackground() -> some View {
    background { DailyBetterBackground() }
  }
}
```

- [ ] **Step 5: Implement destinations and the compact tab bar**

```swift
enum AppDestination: String, Hashable {
  case checkIn
  case timeline
}
```

```swift
import SwiftUI

struct CompactTabBar: View {
  @Binding var selection: AppDestination

  var body: some View {
    HStack(spacing: 6) {
      item(.checkIn, title: "Check In")
      item(.timeline, title: "Timeline")
    }
    .padding(6)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 20).stroke(DailyBetterStyle.hairline) }
    .padding(.horizontal, 24)
  }

  private func item(_ destination: AppDestination, title: String) -> some View {
    Button {
      selection = destination
    } label: {
      HStack(spacing: 8) {
        Image(systemName: destination == .checkIn ? "plus.circle" : "clock")
          .font(.system(size: 20, weight: .medium))
        .frame(width: 20, height: 20)
        Text(title)
      }
      .font(.system(size: 12, weight: .semibold, design: .rounded))
      .foregroundStyle(selection == destination ? Color.white : DailyBetterStyle.muted)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 15)
          .fill(selection == destination ? DailyBetterStyle.tint : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("tab.\(destination.rawValue)")
  }
}
```

- [ ] **Step 6: Replace the root shell with minimal first-pass screens**

```swift
import SwiftData
import SwiftUI

struct RootTabView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var selectedDestination: AppDestination = .checkIn
  @State private var hasBootstrapped = false

  var body: some View {
    ZStack(alignment: .bottom) {
      Group {
        switch selectedDestination {
        case .checkIn:
          NavigationStack { Text("Check In").navigationTitle("Daily Better") }
        case .timeline:
          NavigationStack { Text("Timeline").navigationTitle("Timeline") }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      CompactTabBar(selection: $selectedDestination).padding(.bottom, 8)
    }
    .dailyBetterBackground()
    .task {
      guard !hasBootstrapped else { return }
      hasBootstrapped = true
      AppBootstrapper.bootstrapIfNeeded(in: modelContext)
    }
  }
}
```

- [ ] **Step 7: Regenerate, test, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterUITests/NavigationUITests test
git add Sources/Design Sources/Navigation Sources/App/RootTabView.swift Tests/DailyBetterUITests/NavigationUITests.swift DailyBetter.xcodeproj
git commit -m "feat: add minimal two-tab app shell"
```

Expected: navigation UI test passes before the commit.

## Task 7: Implement Check In and Reflection Screens

**Files:**
- Create: `Sources/Features/CheckIn/MoodSelector.swift`
- Create: `Sources/Features/CheckIn/CheckInView.swift`
- Create: `Sources/Features/CheckIn/ReflectionView.swift`
- Modify: `Sources/App/RootTabView.swift`
- Test: `Tests/DailyBetterUITests/CheckInFlowUITests.swift`

- [ ] **Step 1: Write failing UI tests**

```swift
import XCTest

final class CheckInFlowUITests: XCTestCase {
  func testMoodOnlyReflectShowsLocalReflection() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    app.buttons["mood.overwhelmed"].tap()
    app.buttons["checkIn.reflect"].tap()
    XCTAssertTrue(app.staticTexts["reflection.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["reflection.action"].exists)
  }

}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterUITests/CheckInFlowUITests test
```

Expected: FAIL because the first-pass Check In screen has no mood or reflection controls.

- [ ] **Step 3: Implement accessible mood selection**

```swift
import SwiftUI

struct MoodSelector: View {
  @Binding var selection: CheckInMood?

  var body: some View {
    HStack(spacing: 8) {
      ForEach(CheckInMood.allCases) { mood in
        Button {
          selection = mood
        } label: {
          Text(mood.emoji)
            .font(.system(size: 22))
            .frame(width: 44, height: 44)
            .background(selection == mood ? DailyBetterStyle.tint.opacity(0.16) : DailyBetterStyle.glass)
            .clipShape(Circle())
            .overlay { Circle().stroke(selection == mood ? DailyBetterStyle.tint : DailyBetterStyle.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.title)
        .accessibilityIdentifier("mood.\(mood.rawValue)")
      }
    }
  }
}
```

- [ ] **Step 4: Implement the reflection result screen**

```swift
import SwiftUI

struct ReflectionView: View {
  @Environment(\.dismiss) private var dismiss
  let entry: CheckInEntry

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("\(entry.mood.emoji) \(entry.mood.title) · \(entry.createdAt.formatted(date: .omitted, time: .shortened))")
          .font(.caption.weight(.semibold))
          .foregroundStyle(DailyBetterStyle.tint)
        if let note = entry.noteText {
          Text("“\(note)”").font(.system(.body, design: .serif)).foregroundStyle(DailyBetterStyle.muted)
        }
        Text(entry.reflectionText ?? "")
          .font(.system(size: 25, design: .serif))
          .accessibilityIdentifier("reflection.title")
        VStack(alignment: .leading, spacing: 8) {
          Text("ONE SMALL STEP").font(.caption2.weight(.bold)).foregroundStyle(DailyBetterStyle.tint)
          Text(entry.suggestedActionText ?? "").accessibilityIdentifier("reflection.action")
        }
        .padding(18)
        .background(DailyBetterStyle.glass, in: RoundedRectangle(cornerRadius: 18))
        Button("Done") { dismiss() }
          .buttonStyle(.borderedProminent)
          .tint(DailyBetterStyle.darkAction)
          .frame(maxWidth: .infinity)
      }
      .padding(24)
    }
    .navigationTitle("Reflection")
    .dailyBetterBackground()
  }
}
```

- [ ] **Step 5: Implement `CheckInView`**

```swift
import SwiftData
import SwiftUI

struct CheckInView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var model: CheckInViewModel?

  var body: some View {
    Group {
      if let model {
        @Bindable var model = model
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            HStack {
              Text("Daily Better").font(.subheadline.weight(.bold))
              Spacer()
              NavigationLink(destination: SettingsView()) { Image(systemName: "gearshape") }
                .accessibilityIdentifier("settings.open")
            }
            Text("How are you?").font(.system(size: 34, weight: .bold, design: .rounded))
            MoodSelector(selection: $model.selectedMood)
            Text(model.selectedMood?.title ?? " ")
              .font(.caption.weight(.bold))
              .foregroundStyle(DailyBetterStyle.tint)
              .frame(maxWidth: .infinity)
            TextEditor(text: $model.noteText)
              .frame(minHeight: 190)
              .scrollContentBackground(.hidden)
              .font(.system(size: 21, design: .serif))
              .overlay(alignment: .topLeading) {
                if model.noteText.isEmpty {
                  Text("What's on your mind?")
                    .foregroundStyle(DailyBetterStyle.muted.opacity(0.75))
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
              }
              .accessibilityIdentifier("checkIn.note")
            Button {
              Task { await model.reflect() }
            } label: {
              HStack { Text("Reflect"); Spacer(); Image(systemName: "arrow.right") }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DailyBetterStyle.darkAction)
            .disabled(model.selectedMood == nil || model.isReflecting)
            .accessibilityIdentifier("checkIn.reflect")
            Button("Save without reflection") { Task { await model.saveWithoutReflection() } }
              .disabled(model.selectedMood == nil)
              .frame(maxWidth: .infinity)
              .accessibilityIdentifier("checkIn.saveOnly")
          }
          .padding(24)
          .padding(.bottom, 90)
        }
        .sheet(item: $model.presentedEntry) { entry in
          NavigationStack { ReflectionView(entry: entry) }
        }
        .alert("Couldn't reflect right now", isPresented: failureBinding(model)) {
          Button("Save without reflection") { Task { await model.saveWithoutReflection() } }
          Button("Try again") { Task { await model.reflect() } }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("Your entry is still here.")
        }
      } else {
        ProgressView()
      }
    }
    .task {
      guard model == nil else { return }
      model = CheckInViewModel(
        repository: SwiftDataCheckInRepository(context: modelContext),
        remoteProvider: UnavailableRemoteReflectionProvider()
      )
    }
    .dailyBetterBackground()
  }

  private func failureBinding(_ model: CheckInViewModel) -> Binding<Bool> {
    Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })
  }
}
```

- [ ] **Step 6: Replace the first-pass Check In screen and run tests**

Use `NavigationStack { CheckInView() }` for `.checkIn` in `RootTabView`.

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterUITests/CheckInFlowUITests test
```

Expected: the complete `CheckInFlowUITests` target passes before committing.

- [ ] **Step 7: Commit Check In**

```bash
git add Sources/Features/CheckIn Sources/App/RootTabView.swift Tests/DailyBetterUITests/CheckInFlowUITests.swift DailyBetter.xcodeproj
git commit -m "feat: build check-in and reflection flow"
```

## Task 8: Build Week Navigation and Open Timeline

**Files:**
- Create: `Sources/Features/Timeline/TimelineCalendar.swift`
- Create: `Sources/Features/Timeline/TimelineEntryRow.swift`
- Create: `Sources/Features/Timeline/TimelineView.swift`
- Create: `Sources/Features/Timeline/EntryDetailView.swift`
- Modify: `Sources/App/RootTabView.swift`
- Test: `Tests/DailyBetterTests/TimelineCalendarTests.swift`
- Test: `Tests/DailyBetterUITests/TimelineUITests.swift`

- [ ] **Step 1: Write failing calendar tests**

```swift
import XCTest
@testable import DailyBetter

final class TimelineCalendarTests: XCTestCase {
  func testWeekContainsSevenDates() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30).date!
    let days = TimelineCalendar.week(containing: date, calendar: calendar)
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(calendar.component(.day, from: days.first!), 29)
    XCTAssertEqual(calendar.component(.day, from: days.last!), 5)
  }

  func testEntriesFilterToSelectedDay() {
    let calendar = Calendar(identifier: .gregorian)
    let selected = calendar.startOfDay(for: .now)
    let entries = [
      CheckInEntry(createdAt: selected.addingTimeInterval(3600), mood: .good),
      CheckInEntry(createdAt: selected.addingTimeInterval(-3600), mood: .low)
    ]
    XCTAssertEqual(TimelineCalendar.entries(entries, on: selected, calendar: calendar).count, 1)
  }
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/TimelineCalendarTests test
```

Expected: FAIL because `TimelineCalendar` does not exist.

- [ ] **Step 3: Implement calendar logic**

```swift
import Foundation

enum TimelineCalendar {
  static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
    let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  static func entries(_ entries: [CheckInEntry], on date: Date, calendar: Calendar = .current) -> [CheckInEntry] {
    entries.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.sorted { $0.createdAt > $1.createdAt }
  }
}
```

- [ ] **Step 4: Implement `TimelineEntryRow`**

```swift
import SwiftUI

struct TimelineEntryRow: View {
  let entry: CheckInEntry
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
        .font(.caption2.monospacedDigit())
        .foregroundStyle(DailyBetterStyle.muted)
        .frame(width: 52, alignment: .trailing)
      Circle().fill(DailyBetterStyle.tint).frame(width: 8, height: 8).padding(.top, 4)
      VStack(alignment: .leading, spacing: 7) {
        Text("\(entry.mood.emoji) \(entry.mood.title)")
          .font(.caption.weight(.bold))
          .foregroundStyle(DailyBetterStyle.tint)
        Text(entry.noteText ?? "Only a feeling was recorded.").font(.system(.body, design: .serif))
        if let action = entry.suggestedActionText {
          Text(action)
            .font(.caption)
            .foregroundStyle(DailyBetterStyle.muted)
            .padding(.leading, 10)
            .overlay(alignment: .leading) { Rectangle().fill(DailyBetterStyle.tint.opacity(0.3)).frame(width: 2) }
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
```

- [ ] **Step 5: Implement week navigation and Timeline**

```swift
import SwiftData
import SwiftUI

struct TimelineView: View {
  @Query(sort: \CheckInEntry.createdAt, order: .reverse) private var entries: [CheckInEntry]
  @State private var selectedDate = Calendar.current.startOfDay(for: .now)

  private var week: [Date] { TimelineCalendar.week(containing: selectedDate) }
  private var selectedEntries: [CheckInEntry] { TimelineCalendar.entries(entries, on: selectedDate) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Text("Timeline").font(.subheadline.weight(.bold))
          Spacer()
          NavigationLink(destination: SettingsView()) { Image(systemName: "gearshape") }
            .accessibilityIdentifier("settings.open")
        }
        HStack {
          Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
          Spacer()
          Text(weekRangeTitle).font(.caption.weight(.semibold))
          Spacer()
          Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
        }
        HStack(spacing: 5) {
          ForEach(week, id: \.self) { date in
            Button {
              selectedDate = date
            } label: {
              VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption2)
                Text(date.formatted(.dateTime.day()))
                  .font(.caption.weight(.semibold))
                  .frame(width: 32, height: 32)
                  .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? DailyBetterStyle.tint : Color.clear, in: RoundedRectangle(cornerRadius: 11))
                  .foregroundStyle(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.white : DailyBetterStyle.ink)
                Circle().fill(hasEntries(on: date) ? DailyBetterStyle.tint : Color.clear).frame(width: 4, height: 4)
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(10)
        .background(DailyBetterStyle.glass, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("timeline.week")
        Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.title3.weight(.bold))
        LazyVStack(alignment: .leading, spacing: 28) {
          ForEach(selectedEntries) { entry in
            NavigationLink {
              EntryDetailView(entry: entry)
            } label: {
              TimelineEntryRow(entry: entry)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(24)
      .padding(.bottom, 90)
    }
    .dailyBetterBackground()
  }

  private var weekRangeTitle: String {
    guard let first = week.first, let last = week.last else { return "" }
    return "\(first.formatted(.dateTime.month().day()))–\(last.formatted(.dateTime.month().day()))"
  }
  private func hasEntries(on date: Date) -> Bool {
    entries.contains { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
  }
  private func shiftWeek(_ amount: Int) {
    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: amount, to: selectedDate) ?? selectedDate
  }
}
```

- [ ] **Step 6: Implement entry detail and helpfulness update**

```swift
import SwiftData
import SwiftUI

struct EntryDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var entry: CheckInEntry

  var body: some View {
    ReflectionView(entry: entry)
      .safeAreaInset(edge: .bottom) {
        HStack {
          Button("A little") { setHelpfulness(.better) }
          Button("Not yet") { setHelpfulness(.unchanged) }
        }
        .buttonStyle(.bordered)
        .padding()
      }
  }

  private func setHelpfulness(_ value: Helpfulness) {
    entry.helpfulness = value
    try? modelContext.save()
  }
}
```

- [ ] **Step 7: Add Timeline UI coverage and deterministic seed**

```swift
import XCTest

final class TimelineUITests: XCTestCase {
  func testTimelineShowsWeekAndEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-seed-check-ins"]
    app.launch()
    app.buttons["tab.timeline"].tap()
    XCTAssertTrue(app.otherElements["timeline.week"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Everything piled up today."].exists)
  }

  func testSaveWithoutReflectionAddsTimelineEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    app.buttons["mood.good"].tap()
    app.textViews["checkIn.note"].tap()
    app.textViews["checkIn.note"].typeText("The presentation went well.")
    app.buttons["checkIn.saveOnly"].tap()
    app.buttons["tab.timeline"].tap()
    XCTAssertTrue(app.staticTexts["The presentation went well."].waitForExistence(timeout: 3))
  }
}
```

The deterministic `-seed-check-ins` behavior was implemented in Task 3. Keep that path unchanged so this test never depends on data left by another test run.

- [ ] **Step 8: Replace the first-pass Timeline screen, run affected tests, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/TimelineCalendarTests -only-testing:DailyBetterUITests/TimelineUITests -only-testing:DailyBetterUITests/CheckInFlowUITests test
git add Sources/Features/Timeline Sources/App/RootTabView.swift Sources/Services/AppBootstrapper.swift Tests/DailyBetterTests/TimelineCalendarTests.swift Tests/DailyBetterUITests/TimelineUITests.swift DailyBetter.xcodeproj
git commit -m "feat: add week-based emotional timeline"
```

Expected: calendar, Timeline, and complete Check In UI tests pass.

## Task 9: Replace Settings and Keep One Local Reminder

**Files:**
- Modify: `Sources/Services/NotificationManager.swift`
- Create: `Sources/Services/NotificationRouteStore.swift`
- Create: `Sources/Services/AppNotificationCoordinator.swift`
- Modify: `Sources/App/DailyBetterApp.swift`
- Modify: `Sources/App/RootTabView.swift`
- Replace: `Sources/Views/Settings/SettingsView.swift`
- Test: `Tests/DailyBetterTests/ReminderConfigurationTests.swift`
- Test: `Tests/DailyBetterUITests/SettingsUITests.swift`

- [ ] **Step 1: Write a failing reminder-content test**

```swift
import XCTest
@testable import DailyBetter

final class ReminderConfigurationTests: XCTestCase {
  func testReminderUsesNeutralCheckInCopy() {
    let configuration = ReminderConfiguration(hour: 20, minute: 30)
    XCTAssertEqual(configuration.title, "Daily Better")
    XCTAssertEqual(configuration.body, "Take a moment to check in.")
    XCTAssertEqual(configuration.dateComponents.hour, 20)
    XCTAssertEqual(configuration.dateComponents.minute, 30)
  }

  func testReminderTapRoutesToCheckIn() {
    XCTAssertEqual(NotificationManager.destination(for: NotificationManager.reminderIdentifier), .checkIn)
    XCTAssertNil(NotificationManager.destination(for: "unrelated.notification"))
  }
}
```

- [ ] **Step 2: Run the test to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/ReminderConfigurationTests test
```

Expected: FAIL because `ReminderConfiguration` does not exist.

- [ ] **Step 3: Implement one repeating local reminder**

```swift
import Foundation
import UserNotifications

struct ReminderConfiguration: Equatable {
  let hour: Int
  let minute: Int
  let title = "Daily Better"
  let body = "Take a moment to check in."
  var dateComponents: DateComponents { DateComponents(hour: hour, minute: minute) }
}

enum NotificationManager {
  static let reminderIdentifier = "dailybetter.check-in-reminder"

  static func requestAuthorization() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }

  static func schedule(_ configuration: ReminderConfiguration) async throws {
    remove()
    let content = UNMutableNotificationContent()
    content.title = configuration.title
    content.body = configuration.body
    content.sound = .default
    let trigger = UNCalendarNotificationTrigger(dateMatching: configuration.dateComponents, repeats: true)
    try await UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
    )
  }

  static func remove() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
  }

  static func destination(for identifier: String) -> AppDestination? {
    identifier == reminderIdentifier ? .checkIn : nil
  }
}
```

- [ ] **Step 4: Route notification taps to Check In**

Create the route store:

```swift
import Observation

@MainActor
@Observable
final class NotificationRouteStore {
  static let shared = NotificationRouteStore()
  var pendingDestination: AppDestination?

  private init() {}
}
```

Create the notification delegate:

```swift
import UIKit
import UserNotifications

final class AppNotificationCoordinator: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let destination = NotificationManager.destination(for: response.notification.request.identifier)
    if let destination {
      Task { @MainActor in
        NotificationRouteStore.shared.pendingDestination = destination
      }
    }
    completionHandler()
  }
}
```

Register it in `DailyBetterApp`:

```swift
@UIApplicationDelegateAdaptor(AppNotificationCoordinator.self) private var notificationCoordinator
```

Observe it in `RootTabView`:

```swift
@State private var notificationRouteStore = NotificationRouteStore.shared

// Apply to the root ZStack.
.task { consumeNotificationRoute() }
.onChange(of: notificationRouteStore.pendingDestination) { _, _ in
  consumeNotificationRoute()
}

private func consumeNotificationRoute() {
  guard let destination = notificationRouteStore.pendingDestination else { return }
  selectedDestination = destination
  notificationRouteStore.pendingDestination = nil
}
```

- [ ] **Step 5: Write a failing Settings UI test**

```swift
import XCTest

final class SettingsUITests: XCTestCase {
  func testSettingsContainsOnlyApprovedSections() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-store"]
    app.launch()
    app.buttons["settings.open"].tap()
    XCTAssertTrue(app.staticTexts["Daily reminder"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["AI & privacy"].exists)
    XCTAssertTrue(app.staticTexts["Your data"].exists)
    XCTAssertFalse(app.staticTexts["Theme"].exists)
    XCTAssertFalse(app.staticTexts["Text size"].exists)
  }
}
```

- [ ] **Step 6: Replace Settings with the approved sections**

```swift
import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [AppPreferences]
  @State private var notificationsDenied = false

  private var model: AppPreferences? { preferences.first }

  var body: some View {
    Form {
      Section("Daily reminder") {
        if let model {
          Toggle("Reminder", isOn: reminderBinding(model))
          DatePicker("Time", selection: reminderDateBinding(model), displayedComponents: .hourAndMinute)
            .disabled(!model.reminderEnabled)
        }
        Text("Scheduled locally on this iPhone.").font(.caption).foregroundStyle(DailyBetterStyle.muted)
      }
      Section("AI & privacy") {
        NavigationLink("How reflections work") {
          Text("Mood-only reflections are generated on this device. Written AI reflection will require explicit submission and consent when it is enabled.")
        }
        NavigationLink("Storage & privacy") { Text("Your Timeline is stored on this device.") }
      }
      Section("Your data") {
        NavigationLink("Export timeline") { ExportTimelineView() }
        Button("Delete all entries", role: .destructive) {}
      }
      Section("Support") {
        NavigationLink("Safety resources") { SafetyResourcesView() }
        Button("Send feedback") { openFeedback() }
        Link("Privacy policy", destination: URL(string: "https://guoxinling.github.io/privacy/")!)
      }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Settings")
    .dailyBetterBackground()
    .alert("Notifications are off", isPresented: $notificationsDenied) {
      Button("Open iOS Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
      Button("Cancel", role: .cancel) {}
    }
  }

  private func reminderBinding(_ model: AppPreferences) -> Binding<Bool> {
    Binding(
      get: { model.reminderEnabled },
      set: { enabled in
        Task {
          if enabled, await NotificationManager.requestAuthorization() {
            model.reminderEnabled = true
            try? modelContext.save()
            try? await NotificationManager.schedule(ReminderConfiguration(hour: model.reminderHour, minute: model.reminderMinute))
          } else {
            model.reminderEnabled = false
            try? modelContext.save()
            NotificationManager.remove()
            if enabled { notificationsDenied = true }
          }
        }
      }
    )
  }

  private func reminderDateBinding(_ model: AppPreferences) -> Binding<Date> {
    Binding(
      get: { Calendar.current.date(from: DateComponents(hour: model.reminderHour, minute: model.reminderMinute)) ?? .now },
      set: { date in
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        model.reminderHour = parts.hour ?? 20
        model.reminderMinute = parts.minute ?? 30
        try? modelContext.save()
        guard model.reminderEnabled else { return }
        Task { try? await NotificationManager.schedule(ReminderConfiguration(hour: model.reminderHour, minute: model.reminderMinute)) }
      }
    )
  }

  private func openFeedback() {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = "guoxinling_xisu@163.com"
    components.queryItems = [URLQueryItem(name: "subject", value: "Daily Better Feedback")]
    if let url = components.url { openURL(url) }
  }
}

private struct ExportTimelineView: View {
  var body: some View { Text("Your export is prepared on this device.") }
}

private struct SafetyResourcesView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Daily Better cannot provide crisis care.")
      Text("If you may be in immediate danger, contact local emergency services or a trusted person who can stay with you.")
    }
    .padding()
    .navigationTitle("Safety resources")
  }
}
```

- [ ] **Step 7: Regenerate, run tests, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/ReminderConfigurationTests -only-testing:DailyBetterUITests/SettingsUITests test
git add Sources/Services/NotificationManager.swift Sources/Services/NotificationRouteStore.swift Sources/Services/AppNotificationCoordinator.swift Sources/App/DailyBetterApp.swift Sources/App/RootTabView.swift Sources/Views/Settings/SettingsView.swift Tests/DailyBetterTests/ReminderConfigurationTests.swift Tests/DailyBetterUITests/SettingsUITests.swift DailyBetter.xcodeproj
git commit -m "feat: simplify settings and local reminder"
```

Expected: reminder and Settings tests pass before the commit.

## Task 10: Add Export and Destructive Deletion

**Files:**
- Create: `Sources/Services/TimelineExportService.swift`
- Modify: `Sources/Views/Settings/SettingsView.swift`
- Test: `Tests/DailyBetterTests/TimelineExportServiceTests.swift`
- Test: `Tests/DailyBetterUITests/DataControlsUITests.swift`

- [ ] **Step 1: Write a failing export test**

```swift
import XCTest
@testable import DailyBetter

final class TimelineExportServiceTests: XCTestCase {
  func testExportContainsCurrentEntriesAndLegacyCustomWords() {
    let entry = CheckInEntry(
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      mood: .good,
      noteText: "The presentation went well."
    )
    let legacy = Affirmation(text: "I can begin before I feel ready.", category: .confidence, isCustom: true)
    let export = TimelineExportService.render(entries: [entry], legacyAffirmations: [legacy])
    XCTAssertTrue(export.contains("The presentation went well."))
    XCTAssertTrue(export.contains("Legacy custom words"))
    XCTAssertTrue(export.contains("I can begin before I feel ready."))
  }
}
```

- [ ] **Step 2: Run the test to verify failure**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/TimelineExportServiceTests test
```

Expected: FAIL because `TimelineExportService` does not exist.

- [ ] **Step 3: Implement deterministic plain-text export**

```swift
import Foundation

enum TimelineExportService {
  static func render(entries: [CheckInEntry], legacyAffirmations: [Affirmation]) -> String {
    var lines = ["Daily Better Timeline", ""]
    for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
      lines.append(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
      lines.append("Mood: \(entry.mood.emoji) \(entry.mood.title)")
      if let note = entry.noteText { lines.append(note) }
      if let reflection = entry.reflectionText { lines.append("Reflection: \(reflection)") }
      if let action = entry.suggestedActionText { lines.append("Small step: \(action)") }
      lines.append("")
    }
    let custom = legacyAffirmations.filter(\.isCustom)
    if !custom.isEmpty {
      lines.append("Legacy custom words")
      lines.append(contentsOf: custom.map { "- \($0.text)" })
    }
    return lines.joined(separator: "\n")
  }
}
```

- [ ] **Step 4: Upgrade the first-pass export screen to a shareable file**

```swift
private struct ExportTimelineView: View {
  @Query(sort: \CheckInEntry.createdAt) private var entries: [CheckInEntry]
  @Query private var affirmations: [Affirmation]
  @State private var exportURL: URL?

  var body: some View {
    VStack(spacing: 20) {
      Text("Your export includes Timeline entries and legacy custom words stored on this device.")
      if let exportURL {
        ShareLink(item: exportURL) { Label("Share export", systemImage: "square.and.arrow.up") }
      } else {
        Button("Prepare export") { prepareExport() }
      }
    }
    .padding()
    .navigationTitle("Export timeline")
  }

  private func prepareExport() {
    let text = TimelineExportService.render(entries: entries, legacyAffirmations: affirmations)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Daily-Better-Timeline.txt")
    try? text.write(to: url, atomically: true, encoding: .utf8)
    exportURL = url
  }
}
```

- [ ] **Step 5: Add destructive confirmation**

Add `@State private var confirmsDeleteAll = false`, make the destructive row set it to true, and add:

```swift
.confirmationDialog("Delete every Timeline entry?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
  Button("Delete all entries", role: .destructive) {
    try? SwiftDataCheckInRepository(context: modelContext).deleteAll()
  }
  Button("Cancel", role: .cancel) {}
} message: {
  Text("This cannot be undone. Legacy affirmations are not deleted.")
}
```

- [ ] **Step 6: Add a destructive-control UI test**

```swift
import XCTest

final class DataControlsUITests: XCTestCase {
  func testDeleteAllRequiresConfirmation() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-seed-check-ins"]
    app.launch()
    app.buttons["settings.open"].tap()
    app.buttons["Delete all entries"].tap()
    XCTAssertTrue(app.buttons["Delete all entries"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Cancel"].exists)
  }
}
```

- [ ] **Step 7: Regenerate, run tests, and commit**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DailyBetterTests/TimelineExportServiceTests -only-testing:DailyBetterUITests/DataControlsUITests test
git add Sources/Services/TimelineExportService.swift Sources/Views/Settings/SettingsView.swift Tests/DailyBetterTests/TimelineExportServiceTests.swift Tests/DailyBetterUITests/DataControlsUITests.swift DailyBetter.xcodeproj
git commit -m "feat: add timeline export and deletion"
```

Expected: export and data-control tests pass before the commit.

## Task 11: Remove Legacy UI and Verify the Local Milestone

**Files:**
- Delete: `Sources/Views/Today/TodayView.swift`
- Delete: `Sources/Views/Mood/MoodView.swift`
- Delete: `Sources/Views/Library/LibraryView.swift`
- Delete: `Sources/Views/Library/AddAffirmationView.swift`
- Delete: `Sources/Views/Shared/AffirmationCardView.swift`
- Delete: `Sources/Views/Shared/BrandMarkView.swift`
- Delete: `Sources/Views/Shared/GradientScreenBackground.swift`
- Delete: `Sources/Views/Shared/MoodPickerView.swift`
- Delete: `Sources/Views/Shared/SectionCard.swift`
- Delete: `Sources/Services/ThemePalette.swift`
- Delete: `Sources/Services/TodayAffirmationSelection.swift`
- Modify: `Sources/Models/AppPreferences.swift`
- Modify: `Sources/Models/AppEnums.swift`
- Modify: `Tools/capture_screenshots.sh`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `AppStore/Metadata.md`
- Regenerate: `DailyBetter.xcodeproj/project.pbxproj`

- [ ] **Step 1: Delete obsolete UI and services**

Remove the files listed above. Keep `Affirmation.swift`, `MoodEntry.swift`, and their compatibility enums because migration and export still read them.

- [ ] **Step 2: Preserve stored schema fields while removing obsolete enum APIs**

Run:

```bash
rg -n "ThemeKey|TextScaleKey|LibrarySection|AppTab|DailyReminderSlot" Sources
```

Expected: references only in `AppPreferences.swift`, `AppEnums.swift`, or files already scheduled for deletion.

Keep the persisted `themeKey` and `textScaleKey` string properties so the SwiftData schema can open existing stores, but remove their enum-dependent defaults and computed accessors:

```swift
@Model
final class AppPreferences {
  var id: UUID
  var reminderEnabled: Bool
  var reminderHour: Int
  var reminderMinute: Int
  var themeKey: String
  var textScaleKey: String
  var migrationVersion: Int
  var aiConsentVersion: Int
  var aiConsentAcceptedAt: Date?

  init(
    id: UUID = UUID(),
    reminderEnabled: Bool = false,
    reminderHour: Int = 20,
    reminderMinute: Int = 30,
    themeKey: String = "green",
    textScaleKey: String = "medium",
    migrationVersion: Int = 0,
    aiConsentVersion: Int = 0,
    aiConsentAcceptedAt: Date? = nil
  ) {
    self.id = id
    self.reminderEnabled = reminderEnabled
    self.reminderHour = reminderHour
    self.reminderMinute = reminderMinute
    self.themeKey = themeKey
    self.textScaleKey = textScaleKey
    self.migrationVersion = migrationVersion
    self.aiConsentVersion = aiConsentVersion
    self.aiConsentAcceptedAt = aiConsentAcceptedAt
  }
}
```

Then remove `ThemeKey`, `TextScaleKey`, `LibrarySection`, `AppTab`, and `DailyReminderSlot` from `AppEnums.swift`. Keep `AffirmationCategory` and `MoodKind` for migration/export compatibility.

- [ ] **Step 3: Update screenshot capture for the two-screen product**

Replace the capture loop with:

```zsh
for screen in checkIn timeline; do
  xcrun simctl terminate "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  SIMCTL_CHILD_DAILYBETTER_SCREENSHOT_MODE=1 \
  SIMCTL_CHILD_DAILYBETTER_SCREEN="${screen}" \
    xcrun simctl launch "${udid}" "${BUNDLE_ID}" --args -ui-testing -seed-check-ins >/dev/null
  sleep "${LAUNCH_SETTLE_SECONDS}"
  xcrun simctl io "${udid}" screenshot "${folder}/${screen}.png" >/dev/null
done
```

Map `DAILYBETTER_SCREEN=timeline` to `.timeline` when `RootTabView` creates `selectedDestination`; all other values default to `.checkIn`:

```swift
@State private var selectedDestination: AppDestination =
  ProcessInfo.processInfo.environment["DAILYBETTER_SCREEN"] == "timeline" ? .timeline : .checkIn
```

- [ ] **Step 4: Update product documentation**

Use this exact product summary in README and App Store draft metadata:

```markdown
Daily Better is a private emotional journal for short everyday check-ins.

- Choose one mood and optionally write what is happening.
- Save multiple private entries each day.
- Review entries through a week-based Timeline.
- Use one optional local reminder at a time you choose.
- No account or cloud Timeline sync.
```

Add an `Unreleased` section to `CHANGELOG.md` listing the local Check In, Timeline, migration, export/delete, and reminder changes. State that live AI reflection is not enabled in this milestone.

- [ ] **Step 5: Regenerate and run every test**

```bash
xcodegen generate
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Run an unsigned generic-device build**

```bash
xcodebuild -project DailyBetter.xcodeproj -scheme DailyBetter -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Complete the manual milestone checklist**

Verify on the iPhone 16 Pro simulator:

- New install shows only Check In and Timeline.
- Mood-only Reflect uses local content without a network request.
- Written `Save without reflection` appears in Timeline.
- Written Reflect preserves the draft when the unavailable provider fails.
- Multiple entries appear newest-first on one date.
- Week arrows and date taps filter correctly.
- One reminder can be enabled, changed, and disabled.
- Export includes Timeline entries and legacy custom words.
- Delete All requires confirmation and removes only `CheckInEntry` records.
- Dynamic Type and VoiceOver labels remain usable.

- [ ] **Step 8: Commit the local milestone**

```bash
git add -A
git commit -m "feat: complete local emotional journal foundation"
```

## Follow-On Plans

Do not add these concerns to this implementation branch:

1. **AI Reflection and Safety Plan:** backend proxy, provider selection, response schema, first-use consent, safety classification, crisis-resource catalog, retries, and content-free operational logging.
2. **Release and Compliance Plan:** App Privacy declarations, privacy-policy revision, TestFlight matrix, App Review notes, screenshots, metadata, regulated-medical-device wording, and production rollout.

The AI plan begins only after this local milestone passes all tests and the user approves the provider, deployment platform, expected request volume, and monthly cost ceiling.
