import AVFAudio
import Foundation
import Observation
import Speech

@MainActor
protocol SpeechTranscribing: AnyObject {
  func requestAuthorization() async throws
  func start(
    locale: Locale,
    onTranscript: @escaping (String) -> Void,
    onFailure: @escaping (Error) -> Void
  ) async throws
  func stop()
  func cancel()
}

@MainActor
@Observable
final class SpeechToTextController {
  var isListening = false

  private let transcriber: SpeechTranscribing
  private var baseText = ""
  private var activeTranscript = ""

  init(transcriber: SpeechTranscribing? = nil) {
    self.transcriber = transcriber ?? AppleSpeechTranscriber()
  }

  func start(
    existingText: String,
    onTranscript: @escaping (String) -> Void,
    onFailure: @escaping (Error) -> Void = { _ in }
  ) async throws {
    cancel()
    try await transcriber.requestAuthorization()
    baseText = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
    activeTranscript = ""
    let recognitionLocale = SpeechRecognitionLocaleResolver.locale()
    try await transcriber.start(locale: recognitionLocale) { [weak self] transcript in
      guard let self, let text = self.nextCombinedTranscript(transcript) else { return }
      onTranscript(text)
    } onFailure: { [weak self] error in
      guard let self else { return }
      isListening = false
      baseText = ""
      activeTranscript = ""
      onFailure(error)
    }
    isListening = true
  }

  func toggle(
    existingText: String,
    onTranscript: @escaping (String) -> Void,
    onFailure: @escaping (Error) -> Void = { _ in }
  ) async throws {
    if isListening {
      stop()
    } else {
      try await start(existingText: existingText, onTranscript: onTranscript, onFailure: onFailure)
    }
  }

  func stop() {
    guard isListening else { return }
    transcriber.stop()
    isListening = false
  }

  func cancel() {
    transcriber.cancel()
    isListening = false
    baseText = ""
    activeTranscript = ""
  }

  private func nextCombinedTranscript(_ transcript: String) -> String? {
    let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTranscript.isEmpty else { return nil }
    guard cleanTranscript.count >= activeTranscript.count else {
      return nil
    }
    activeTranscript = cleanTranscript
    return Self.combined(baseText: baseText, transcript: cleanTranscript)
  }

  private static func combined(baseText: String, transcript: String) -> String {
    let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !baseText.isEmpty else { return cleanTranscript }
    guard !cleanTranscript.isEmpty else { return baseText }
    return "\(baseText) \(cleanTranscript)"
  }
}

enum SpeechRecognitionLocaleResolver {
  static func locale(
    currentLocale: Locale = .current,
    preferredLanguageIdentifiers: [String] = Locale.preferredLanguages
  ) -> Locale {
    if currentLocale.language.languageCode?.identifier == "zh" {
      return Locale(identifier: "zh-CN")
    }

    if preferredLanguageIdentifiers.contains(where: { $0.lowercased().hasPrefix("zh") }) {
      return Locale(identifier: "zh-CN")
    }

    if currentLocale.region?.identifier.uppercased() == "CN" {
      return Locale(identifier: "zh-CN")
    }

    return currentLocale
  }
}

final class AppleSpeechTranscriber: NSObject, SpeechTranscribing {
  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var isStopping = false
  private var hasDeliveredFailure = false

  func requestAuthorization() async throws {
    let speechStatus = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
    speechLog("speech authorization status=\(speechStatus.rawValue)")
    guard speechStatus == .authorized else {
      throw SpeechToTextError.speechRecognitionDenied
    }

    let microphoneAllowed = await requestMicrophonePermission()
    speechLog("microphone permission allowed=\(microphoneAllowed)")
    guard microphoneAllowed else {
      throw SpeechToTextError.microphoneDenied
    }
  }

  func start(
    locale: Locale,
    onTranscript: @escaping (String) -> Void,
    onFailure: @escaping (Error) -> Void
  ) async throws {
    cancel()
    isStopping = false
    hasDeliveredFailure = false

    guard let recognizer = availableRecognizer(preferredLocale: locale) else {
      speechLog("no available speech recognizer locale=\(locale.identifier)")
      throw SpeechToTextError.recognizerUnavailable
    }
    speechLog(
      "using recognizer locale=\(recognizer.locale.identifier) isAvailable=\(recognizer.isAvailable) supportsOnDeviceRecognition=\(recognizer.supportsOnDeviceRecognition)"
    )

    let audioEngine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }
    speechLog("request requiresOnDeviceRecognition=\(request.requiresOnDeviceRecognition)")

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    speechLog(
      "input format sampleRate=\(recordingFormat.sampleRate) channels=\(recordingFormat.channelCount)"
    )
    guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      speechLog("audio input unavailable")
      throw SpeechToTextError.audioInputUnavailable
    }
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      request.append(buffer)
    }

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      if let transcript = result?.bestTranscription.formattedString {
        Task { @MainActor in
          speechLog("received transcript length=\(transcript.count) isFinal=\(result?.isFinal == true)")
          onTranscript(transcript)
        }
      }

      if let error {
        Task { @MainActor in
          let nsError = error as NSError
          speechLog(
            "recognition error domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)"
          )
          guard let self, !self.isStopping, !self.hasDeliveredFailure else { return }
          self.hasDeliveredFailure = true
          onFailure(SpeechToTextError.recognitionFailed(error.localizedDescription))
        }
      }

      if result?.isFinal == true || error != nil {
        Task { @MainActor in
          self?.finishRecognitionSession()
        }
      }
    }

    do {
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      inputNode.removeTap(onBus: 0)
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      recognitionTask?.cancel()
      recognitionTask = nil
      speechLog("audio engine start failed=\(error.localizedDescription)")
      throw error
    }

    self.audioEngine = audioEngine
    recognitionRequest = request
    speechLog("audio engine started")
  }

  func stop() {
    speechLog("stop requested")
    isStopping = true
    recognitionRequest?.endAudio()
    stopAudioCapture(deactivateSession: false)
    // Keep the request alive until Speech delivers its final callback.
  }

  func cancel() {
    speechLog("cancel requested")
    isStopping = true
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    stopAudioCapture(deactivateSession: true)
    recognitionTask = nil
    recognitionRequest = nil
  }

  private func availableRecognizer(preferredLocale: Locale) -> SFSpeechRecognizer? {
    var candidates: [Locale] = []
    if prefersChineseSpeech(preferredLocale: preferredLocale) {
      candidates.append(Locale(identifier: "zh-CN"))
    }

    candidates.append(preferredLocale)
    candidates.append(contentsOf: Locale.preferredLanguages.map(Locale.init(identifier:)))
    candidates.append(Locale(identifier: "en-US"))

    var seenIdentifiers = Set<String>()
    for candidate in candidates where seenIdentifiers.insert(candidate.identifier).inserted {
      if let recognizer = SFSpeechRecognizer(locale: candidate), recognizer.isAvailable {
        return recognizer
      }
    }

    if let recognizer = SFSpeechRecognizer(), recognizer.isAvailable {
      return recognizer
    }

    return nil
  }

  private func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
      if #available(iOS 17.0, *) {
        AVAudioApplication.requestRecordPermission { allowed in
          continuation.resume(returning: allowed)
        }
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
          continuation.resume(returning: allowed)
        }
      }
    }
  }

  private func finishRecognitionSession() {
    speechLog("finish recognition session")
    stopAudioCapture(deactivateSession: true)
    recognitionTask = nil
    recognitionRequest = nil
  }

  private func stopAudioCapture(deactivateSession: Bool) {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    if deactivateSession {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  private func prefersChineseSpeech(preferredLocale: Locale) -> Bool {
    if preferredLocale.language.languageCode?.identifier == "zh" {
      return true
    }

    if preferredLocale.region?.identifier.uppercased() == "CN" {
      return true
    }

    return Locale.preferredLanguages.contains { identifier in
      identifier.lowercased().hasPrefix("zh")
    }
  }
}

enum SpeechToTextError: Error {
  case speechRecognitionDenied
  case microphoneDenied
  case recognizerUnavailable
  case audioInputUnavailable
  case recognitionFailed(String)
}

extension SpeechToTextError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .speechRecognitionDenied:
      "Speech recognition permission is required."
    case .microphoneDenied:
      "Microphone permission is required."
    case .recognizerUnavailable:
      "Speech recognition is not available for this language right now."
    case .audioInputUnavailable:
      "Audio input is not available on this device."
    case .recognitionFailed(let reason):
      reason
    }
  }
}

enum SpeechToTextFailureMessage {
  static func text(for error: Error, isSimulator: Bool = isRunningOnSimulator) -> String {
    if let speechError = error as? SpeechToTextError {
      switch speechError {
      case .speechRecognitionDenied, .microphoneDenied:
        return "Check microphone and speech recognition permissions, then try again."
      case .recognizerUnavailable:
        return "Speech recognition is not available for this language right now."
      case .audioInputUnavailable:
        return "Audio input is not available on this device."
      case .recognitionFailed(let reason):
        if isSimulator && reason.localizedCaseInsensitiveContains("Failed to initialize recognizer") {
          return "Voice input may not be available in Simulator. Please test on a real iPhone, or type your note for now."
        }
        return genericRetryMessage
      }
    }

    return genericRetryMessage
  }

  private static let genericRetryMessage =
    "Voice input could not start. Please try again, or type your note for now."

  private static var isRunningOnSimulator: Bool {
    #if targetEnvironment(simulator)
      true
    #else
      false
    #endif
  }
}

private func speechLog(_ message: String) {
  #if DEBUG
    print("[SpeechToText] \(message)")
  #endif
}
