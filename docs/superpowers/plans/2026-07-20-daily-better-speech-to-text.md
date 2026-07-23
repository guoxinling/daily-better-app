# Daily Better Speech-to-Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a privacy-conscious `Speak to text` composer action that transcribes live microphone input into editable journal text without storing audio or calling the Daily Better AI backend.

**Architecture:** A protocol-backed `AppleSpeechTranscriber` combines `SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`, and `AVAudioEngine`. `JournalTextEditor` wraps `UITextView` to retain an insertion range on iOS 17, while `SpeechComposerController` replaces one provisional transcript segment instead of repeatedly appending partial results. The existing reflection request receives only the final edited note text when the user later taps Reflect.

**Tech Stack:** Swift 5, SwiftUI, UIKit, Speech, AVFAudio, Observation, XCTest, XCUITest, XcodeGen, iOS 17+

## Global Constraints

- Complete the Timeline-first core plan before starting this plan.
- Speech transcription does not call DeepSeek or any Daily Better AI endpoint.
- No audio file or replayable audio data may be persisted.
- Request microphone and speech-recognition permissions only after `Speak to text` is tapped.
- Prefer on-device recognition when the current recognizer supports it; otherwise Apple speech recognition may require network access.
- The privacy copy must accurately disclose the Apple speech-processing path.
- Final text remains fully editable and is inserted at the current text selection.
- Stop transcription when the user stops, leaves the composer, backgrounds the app, saves, or starts reflection.
- Typing, Save, and Reflect remain usable if speech is denied, unavailable, or interrupted.
- Use `iPhone 17 Pro, iOS 26.5` for Simulator commands; perform final microphone validation on a physical iPhone.

---

### Task 1: Add usage descriptions and protocol-level permission states

**Files:**
- Create: `Sources/Features/Speech/SpeechTranscribing.swift`
- Create: `Tests/DailyBetterTests/SpeechAuthorizationTests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `SpeechAuthorizationState`
- Produces: `SpeechTranscriptionEvent`
- Produces: `@MainActor protocol SpeechTranscribing`

- [ ] **Step 1: Write the failing authorization-domain test**

```swift
func testSpeechCanStartOnlyWhenBothPermissionsAreAuthorized() {
  XCTAssertTrue(SpeechAuthorizationState.authorized.canStart)
  XCTAssertFalse(SpeechAuthorizationState.notDetermined.canStart)
  XCTAssertFalse(SpeechAuthorizationState.denied.canStart)
  XCTAssertFalse(SpeechAuthorizationState.restricted.canStart)
  XCTAssertFalse(SpeechAuthorizationState.unavailable.canStart)
}
```

- [ ] **Step 2: Run the test and verify the domain type is missing**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/SpeechAuthorizationTests
```

Expected: FAIL because the speech domain types do not exist.

- [ ] **Step 3: Define the protocol boundary**

```swift
enum SpeechAuthorizationState: Equatable, Sendable {
  case notDetermined
  case authorized
  case denied
  case restricted
  case unavailable

  var canStart: Bool { self == .authorized }
}

enum SpeechTranscriptionEvent: Equatable, Sendable {
  case partial(String)
  case final(String)
}

@MainActor
protocol SpeechTranscribing: AnyObject {
  var authorizationState: SpeechAuthorizationState { get }
  func requestAuthorization() async -> SpeechAuthorizationState
  func start(locale: Locale) throws -> AsyncThrowingStream<SpeechTranscriptionEvent, Error>
  func stop()
  func cancel()
}
```

- [ ] **Step 4: Add exact Info.plist-generated usage descriptions**

Add to `project.yml`:

```yaml
INFOPLIST_KEY_NSMicrophoneUsageDescription: Daily Better uses the microphone only while you speak to turn your words into editable journal text. Audio is not saved.
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription: Daily Better uses Apple speech recognition to turn your voice into editable journal text.
```

- [ ] **Step 5: Regenerate and run the domain test**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/SpeechAuthorizationTests
```

Expected: PASS and the generated target contains both usage-description keys.

- [ ] **Step 6: Commit the speech boundary and configuration**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Speech/SpeechTranscribing.swift \
  Tests/DailyBetterTests/SpeechAuthorizationTests.swift
git commit -m "feat: define speech transcription permissions"
```

### Task 2: Implement the Apple speech transcriber without audio files

**Files:**
- Create: `Sources/Features/Speech/AppleSpeechTranscriber.swift`
- Create: `Tests/DailyBetterTests/AppleSpeechTranscriberStateTests.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `AppleSpeechTranscriber: SpeechTranscribing`
- Uses: `AVAudioApplication.requestRecordPermission`, `SFSpeechRecognizer.requestAuthorization`
- Uses: `SFSpeechAudioBufferRecognitionRequest` and `AVAudioEngine.inputNode`

- [ ] **Step 1: Write failing state-cleanup tests around injected adapters**

Inject permission and engine adapters so tests do not open the Simulator microphone. Cover:

```swift
func testStartConfiguresPartialDictationAndOnDevicePreference() async throws {
  recognizer.supportsOnDeviceRecognition = true
  let stream = try transcriber.start(locale: Locale(identifier: "en_US"))

  XCTAssertTrue(request.shouldReportPartialResults)
  XCTAssertTrue(request.addsPunctuation)
  XCTAssertTrue(request.requiresOnDeviceRecognition)
  XCTAssertEqual(request.taskHint, .dictation)
  XCTAssertTrue(engine.didInstallInputTap)
  _ = stream
}

func testStopRemovesTapAndEndsAudioWithoutWritingFiles() async throws {
  _ = try transcriber.start(locale: Locale(identifier: "en_US"))
  transcriber.stop()

  XCTAssertTrue(engine.didRemoveInputTap)
  XCTAssertTrue(request.didEndAudio)
}
```

Also cover unavailable recognizer, zero-channel input format, recognition error, cancellation, and repeated start. The transcriber has no filesystem adapter or file URL API; enforce that architecture in the constructor test so audio cannot be persisted through this service.

- [ ] **Step 2: Run tests and verify the service is absent**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/AppleSpeechTranscriberStateTests
```

Expected: FAIL because `AppleSpeechTranscriber` is missing.

- [ ] **Step 3: Implement current iOS 17 permission APIs**

Compute combined authorization from `AVAudioApplication.shared.recordPermission` and `SFSpeechRecognizer.authorizationStatus()`. When either is undetermined, bridge both callback APIs with checked continuations. Return authorized only when both grant access.

- [ ] **Step 4: Implement live recognition**

In `start(locale:)`, configure `AVAudioSession.sharedInstance()` with category `.record`, mode `.measurement`, activate it, then create the request:

```swift
let recognizer = try makeRecognizer(locale)
let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true
request.addsPunctuation = true
request.taskHint = .dictation
request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

let input = audioEngine.inputNode
let format = input.outputFormat(forBus: 0)
guard format.sampleRate > 0, format.channelCount > 0 else {
  throw SpeechTranscriptionError.audioInputUnavailable
}

input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
  request.append(buffer)
}
audioEngine.prepare()
try audioEngine.start()
```

Yield `.partial(result.bestTranscription.formattedString)` until `result.isFinal`, then yield `.final(...)`, clean up, and finish the stream. If on-device recognition is unsupported, leave `requiresOnDeviceRecognition` false; no Daily Better server is involved.

- [ ] **Step 5: Centralize cleanup**

One idempotent cleanup method must stop the engine, remove the input tap, end or cancel the request/task, deactivate the audio session, nil retained framework objects, and finish the stream exactly once. `deinit`, stop, cancel, error, and final result all use it.

- [ ] **Step 6: Run state tests**

Run the Step 2 command.

Expected: PASS with no filesystem dependency and idempotent cleanup.

- [ ] **Step 7: Commit the Apple transcriber**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Speech/AppleSpeechTranscriber.swift \
  Tests/DailyBetterTests/AppleSpeechTranscriberStateTests.swift
git commit -m "feat: transcribe journal speech with apple frameworks"
```

### Task 3: Add a selection-aware journal text editor

**Files:**
- Create: `Sources/Features/CheckIn/JournalTextEditor.swift`
- Create: `Tests/DailyBetterTests/JournalTextInsertionTests.swift`
- Modify: `Sources/Features/CheckIn/CheckInView.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `JournalTextSelection(location:length:)`
- Produces: `JournalTextEditor(text:selection:isFocused:)`
- Produces: `String.replacingUTF16Range(_:with:)`

- [ ] **Step 1: Write failing UTF-16 insertion tests**

```swift
func testInsertionUsesCurrentSelectionAndHandlesEmoji() {
  let text = "Calm today"
  let selection = JournalTextSelection(location: 5, length: 0)

  let result = text.replacingUTF16Range(selection, with: "and steady ")

  XCTAssertEqual(result.text, "Calm and steady today")
  XCTAssertEqual(result.selection.location, 16)
}

func testReplacementTreatsEmojiAsTwoUTF16CodeUnits() {
  let result = "Calm 😊 today".replacingUTF16Range(
    .init(location: 5, length: 2),
    with: "🙂"
  )
  XCTAssertEqual(result.text, "Calm 🙂 today")
  XCTAssertEqual(result.selection.location, 7)
}

func testPartialTranscriptReplacesOnlyItsPreviousRange() {
  let first = "Before after".replacingUTF16Range(.init(location: 7, length: 0), with: "hello")
  let second = first.text.replacingUTF16Range(
    .init(location: 7, length: 5),
    with: "hello world"
  )
  XCTAssertEqual(second.text, "Before hello worldafter")
}
```

- [ ] **Step 2: Run tests and verify selection helpers are missing**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/JournalTextInsertionTests
```

Expected: FAIL because selection-aware replacement is absent.

- [ ] **Step 3: Implement UTF-16-safe replacement**

Use `NSString` for `NSRange` compatibility with `UITextView`:

```swift
struct JournalTextSelection: Equatable, Sendable {
  var location: Int
  var length: Int
}

extension String {
  func replacingUTF16Range(
    _ selection: JournalTextSelection,
    with replacement: String
  ) -> (text: String, selection: JournalTextSelection) {
    let source = self as NSString
    let location = min(max(0, selection.location), source.length)
    let length = min(max(0, selection.length), source.length - location)
    let safe = NSRange(location: location, length: length)
    let updated = source.replacingCharacters(in: safe, with: replacement)
    return (updated, .init(location: safe.location + (replacement as NSString).length, length: 0))
  }
}
```

- [ ] **Step 4: Wrap UITextView and preserve selection**

`JournalTextEditor` is a `UIViewRepresentable` with bindings for text, `JournalTextSelection`, and focus. The coordinator implements `textViewDidChange` and `textViewDidChangeSelection`; `updateUIView` updates text only when different and restores the bound selected range after programmatic transcript updates.

- [ ] **Step 5: Replace TextEditor and run tests**

Regenerate and run the Step 2 test, then `CheckInFlowUITests`.

Expected: insertion tests PASS and existing keyboard/layout tests remain PASS.

- [ ] **Step 6: Commit the journal editor**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/CheckIn/JournalTextEditor.swift \
  Sources/Features/CheckIn/CheckInView.swift \
  Tests/DailyBetterTests/JournalTextInsertionTests.swift
git commit -m "feat: preserve journal text selection"
```

### Task 4: Coordinate provisional speech text with the composer

**Files:**
- Create: `Sources/Features/Speech/SpeechComposerController.swift`
- Create: `Tests/DailyBetterTests/SpeechComposerControllerTests.swift`
- Modify: `Sources/Features/CheckIn/CheckInViewModel.swift`
- Modify: `project.yml`
- Regenerate: `DailyBetter.xcodeproj`

**Interfaces:**
- Produces: `SpeechComposerController.state`
- Produces: `start(text:selection:locale:)`, `finish() async`, and `cancel()`
- Produces: `SpeechComposerState.idle`, `.requestingPermission`, `.listening`, `.failed`

- [ ] **Step 1: Write failing controller tests with a fake transcriber**

```swift
func testPartialEventsReplaceOneProvisionalSegment() async {
  let controller = makeController(events: [.partial("hello"), .partial("hello world")])
  await controller.start(text: "Before after", selection: .init(location: 7, length: 0))

  XCTAssertEqual(controller.text, "Before hello worldafter")
  XCTAssertEqual(controller.provisionalRange, .init(location: 7, length: 11))
}

func testFinalEventLeavesEditableTextAndReturnsIdle() async {
  let controller = makeController(events: [.partial("hello"), .final("hello.")])
  await controller.start(text: "", selection: .init(location: 0, length: 0))

  XCTAssertEqual(controller.text, "hello.")
  XCTAssertEqual(controller.state, .idle)
  XCTAssertNil(controller.provisionalRange)
}

func testDeniedPermissionDoesNotChangeDraft() async {
  transcriber.authorizationResult = .denied
  await controller.start(text: "Keep me", selection: .init(location: 7, length: 0))

  XCTAssertEqual(controller.text, "Keep me")
  XCTAssertEqual(controller.state, .failed(.permissionDenied))
}
```

Add tests for stop, cancel, background interruption, and a recognizer error after partial text.

- [ ] **Step 2: Run controller tests and verify missing state machine**

```bash
xcodegen generate
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/SpeechComposerControllerTests
```

Expected: FAIL because the controller is absent.

- [ ] **Step 3: Implement one provisional replacement range**

Capture the insertion selection at start. On the first partial event, replace that selection and remember the inserted range. On subsequent partial/final events, replace only the remembered range. On final, collapse selection after final text and clear the provisional marker.

Expose `text` and `selection` changes through closures or bindings so `CheckInViewModel.noteText` remains the source of truth.

- [ ] **Step 4: Define interruption semantics**

- `finish() async` calls transcriber stop, waits for the stream-consumer task to finish, and retains the latest transcript. Guard the wait with a two-second timeout; on timeout cancel the recognition task and retain the latest visible text.
- `cancel()` cancels recognition and removes only the current provisional segment.
- recognition error retains the latest visible transcript as editable text and enters failed state.
- composer dismissal calls cancel before draft cleanup.
- Save and Reflect await `finish()` before reading `noteText` and starting persistence or reflection.

- [ ] **Step 5: Run controller and ViewModel tests**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests/SpeechComposerControllerTests \
  -only-testing:DailyBetterTests/CheckInViewModelTests
```

Expected: PASS; reflection requests contain only the resulting note string.

- [ ] **Step 6: Commit speech composition state**

```bash
git add project.yml DailyBetter.xcodeproj \
  Sources/Features/Speech/SpeechComposerController.swift \
  Sources/Features/CheckIn/CheckInViewModel.swift \
  Tests/DailyBetterTests/SpeechComposerControllerTests.swift
git commit -m "feat: merge live speech into journal text"
```

### Task 5: Add composer speech controls, lifecycle handling, and privacy copy

**Files:**
- Modify: `Sources/Features/CheckIn/CheckInView.swift`
- Modify: `Sources/Views/Settings/SettingsView.swift`
- Modify: `AppStore/PrivacyPolicy.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `Tests/DailyBetterUITests/CheckInFlowUITests.swift`
- Modify: `Tests/DailyBetterUITests/SettingsUITests.swift`

**Interfaces:**
- Produces identifiers: `checkIn.speech.start`, `checkIn.speech.stop`, `checkIn.speech.status`
- Consumes: `SpeechComposerController`

- [ ] **Step 1: Add failing UI tests with stub speech states**

Use launch arguments for authorized success and denied states:

```swift
func testSpeakToTextShowsLiveTextAndStopAction() {
  let app = launchComposer(additionalArguments: ["-stub-speech-success"])
  app.buttons["checkIn.speech.start"].tap()

  XCTAssertTrue(app.buttons["checkIn.speech.stop"].waitForExistence(timeout: 2))
  XCTAssertTrue(app.staticTexts["checkIn.speech.status"].exists)
  XCTAssertTrue(app.textViews["checkIn.note"].value as? String == "A calmer moment.")
}

func testDeniedSpeechOffersIOSSettingsAndKeepsTypingAvailable() {
  let app = launchComposer(additionalArguments: ["-stub-speech-denied"])
  app.buttons["checkIn.speech.start"].tap()

  XCTAssertTrue(app.alerts["Speech access is off"].waitForExistence(timeout: 2))
  XCTAssertTrue(app.alerts.buttons["Open iOS Settings"].exists)
  XCTAssertTrue(app.textViews["checkIn.note"].isHittable)
}
```

- [ ] **Step 2: Run UI tests and verify speech controls are absent**

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterUITests/CheckInFlowUITests \
  -only-testing:DailyBetterUITests/SettingsUITests
```

Expected: FAIL because the controls and disclosure are absent.

- [ ] **Step 3: Add Speak/Stop controls and lifecycle handling**

Place `Speak to text` beside `Add photo`, not in the fixed Save/Reflect dock. While listening, replace it with a visible `Stop listening` control and status such as `Listening...`. Observe `scenePhase`; when it becomes inactive or background, stop recognition and retain current text.

Before Save or Reflect, await `controller.finish()` and only then invoke the ViewModel action. Disable repeat start while requesting permission or listening. Keep the fixed actions visible and keyboard-safe. Add a UI-test stub whose final event arrives only after stop, proving the final words are included in the saved note.

- [ ] **Step 4: Add denied and unavailable recovery**

For denied/restricted permission show:

```text
Speech access is off
You can keep typing, or allow Microphone and Speech Recognition access in iOS Settings.
```

Actions are `Open iOS Settings` and `Not now`. For service/network unavailability, show a non-permission message and leave manual typing active.

- [ ] **Step 5: Update privacy-facing copy**

Settings `Storage & privacy`, README, and `AppStore/PrivacyPolicy.md` must state:

```text
Speak to text uses Apple's speech recognition. Daily Better does not save an audio recording or send microphone audio to the Daily Better reflection service. On-device recognition is used when available; Apple speech recognition may otherwise require a network connection.
```

Add the feature under `Unreleased` in CHANGELOG.

- [ ] **Step 6: Run automated regressions**

Run the Step 2 command, then:

```bash
xcodebuild test -project DailyBetter.xcodeproj -scheme DailyBetter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:DailyBetterTests \
  -only-testing:DailyBetterUITests/CheckInFlowUITests \
  -only-testing:DailyBetterUITests/SettingsUITests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Perform physical-iPhone validation**

On a registered iPhone, verify:

```text
first tap requests Microphone and Speech Recognition permissions
partial words replace rather than duplicate
Stop leaves editable text
backgrounding stops the microphone indicator
Save and Reflect stop listening before persistence/network work
denial leaves typing usable
no audio file appears in Application Support or Documents
```

- [ ] **Step 8: Commit speech UI and disclosures**

```bash
git add Sources/Features/CheckIn/CheckInView.swift \
  Sources/Views/Settings/SettingsView.swift \
  AppStore/PrivacyPolicy.md README.md CHANGELOG.md \
  Tests/DailyBetterUITests/CheckInFlowUITests.swift \
  Tests/DailyBetterUITests/SettingsUITests.swift
git commit -m "feat: add private speech-to-text check-ins"
```
