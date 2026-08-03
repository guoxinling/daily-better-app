import XCTest
@testable import DailyBetter

@MainActor
final class SpeechToTextControllerTests: XCTestCase {
  func testTranscriptAppendsToExistingNoteWithSingleSpace() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)
    var latestText = ""

    try await controller.start(existingText: "I feel tired.") { text in
      latestText = text
    }
    transcriber.emit("Need rest")

    XCTAssertEqual(latestText, "I feel tired. Need rest")
    XCTAssertTrue(controller.isListening)
  }

  func testTranscriptKeepsLongerPartialWhenRecognizerEmitsShorterUpdate() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)
    var latestText = ""

    try await controller.start(existingText: "Before") { text in
      latestText = text
    }
    transcriber.emit("I feel tired today")
    transcriber.emit("I feel")
    transcriber.emit("")

    XCTAssertEqual(latestText, "Before I feel tired today")
  }

  func testSpeechLocalePrefersChineseForChinaRegion() {
    let locale = SpeechRecognitionLocaleResolver.locale(
      currentLocale: Locale(identifier: "en_CN"),
      preferredLanguageIdentifiers: ["en-CN", "en-US"]
    )

    XCTAssertEqual(locale.identifier, "zh-CN")
  }

  func testSpeechLocalePrefersChineseWhenPreferredLanguageIsChinese() {
    let locale = SpeechRecognitionLocaleResolver.locale(
      currentLocale: Locale(identifier: "en_US"),
      preferredLanguageIdentifiers: ["zh-Hans-CN", "en-US"]
    )

    XCTAssertEqual(locale.identifier, "zh-CN")
  }

  func testSpeechLocaleKeepsCurrentLocaleOutsideChineseContext() {
    let locale = SpeechRecognitionLocaleResolver.locale(
      currentLocale: Locale(identifier: "en_US"),
      preferredLanguageIdentifiers: ["en-US"]
    )

    XCTAssertEqual(locale.identifier, "en_US")
  }

  func testStopClearsListeningStateAndStopsTranscriber() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)

    try await controller.start(existingText: "") { _ in }
    controller.stop()

    XCTAssertFalse(controller.isListening)
    XCTAssertEqual(transcriber.stopCallCount, 1)
  }

  func testStopKeepsFinalTranscriptCallbackAvailable() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)
    var latestText = ""

    try await controller.start(existingText: "Before") { text in
      latestText = text
    }
    controller.stop()
    transcriber.emit("after stop")

    XCTAssertEqual(latestText, "Before after stop")
  }

  func testAsyncRecognitionFailureClearsListeningStateAndReportsFailure() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)
    var capturedError: Error?

    try await controller.start(existingText: "") { _ in
    } onFailure: { error in
      capturedError = error
    }
    transcriber.emitFailure(SpeechToTextError.recognitionFailed("Failed to initialize recognizer"))

    XCTAssertFalse(controller.isListening)
    XCTAssertNotNil(capturedError)
  }

  func testRecognizerInitializationFailureUsesSimulatorSpecificMessage() {
    let message = SpeechToTextFailureMessage.text(
      for: SpeechToTextError.recognitionFailed("Failed to initialize recognizer"),
      isSimulator: true
    )

    XCTAssertEqual(
      message,
      "Voice input may not be available in Simulator. Please test on a real iPhone, or type your note for now."
    )
  }

  func testGenericRecognitionFailureUsesRetryMessage() {
    let message = SpeechToTextFailureMessage.text(
      for: SpeechToTextError.recognitionFailed("The operation could not be completed."),
      isSimulator: false
    )

    XCTAssertEqual(message, "Voice input could not start. Please try again, or type your note for now.")
  }

  func testStartCancelsStaleSpeechSessionBeforeStarting() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)

    try await controller.start(existingText: "") { _ in }

    XCTAssertEqual(transcriber.cancelCallCount, 1)
    XCTAssertTrue(controller.isListening)
  }

  func testCancelClearsListeningStateAndCancelsTranscriber() async throws {
    let transcriber = SpeechTranscriberSpy()
    let controller = SpeechToTextController(transcriber: transcriber)

    try await controller.start(existingText: "") { _ in }
    controller.cancel()

    XCTAssertFalse(controller.isListening)
    XCTAssertEqual(transcriber.cancelCallCount, 2)
  }
}

@MainActor
private final class SpeechTranscriberSpy: SpeechTranscribing {
  private var onTranscript: ((String) -> Void)?
  private var onFailure: ((Error) -> Void)?
  private(set) var stopCallCount = 0
  private(set) var cancelCallCount = 0

  func requestAuthorization() async throws {}

  func start(
    locale: Locale,
    onTranscript: @escaping (String) -> Void,
    onFailure: @escaping (Error) -> Void
  ) async throws {
    self.onTranscript = onTranscript
    self.onFailure = onFailure
  }

  func stop() {
    stopCallCount += 1
  }

  func cancel() {
    cancelCallCount += 1
    onTranscript = nil
  }

  func emit(_ transcript: String) {
    onTranscript?(transcript)
  }

  func emitFailure(_ error: Error) {
    onFailure?(error)
  }
}
