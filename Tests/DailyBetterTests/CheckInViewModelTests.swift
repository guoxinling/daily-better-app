import XCTest
@testable import DailyBetter

@MainActor
final class CheckInViewModelTests: XCTestCase {
  func testDraftTrimsWhitespaceAndNewlines() {
    let draft = CheckInDraft(mood: .bright, noteText: "  A steady moment. \n")

    XCTAssertEqual(draft.trimmedNote, "A steady moment.")
    XCTAssertEqual(CheckInDraft().trimmedNote, "")
  }

  func testSaveWithoutReflectionPersistsAndClearsDraftWithoutCallingProviders() async {
    let repository = InMemoryCheckInRepository()
    let localProvider = ReflectionProviderSpy(result: .success(.stub(source: .local)))
    let remoteProvider = ReflectionProviderSpy(result: .success(.stub(source: .ai)))
    let viewModel = CheckInViewModel(
      repository: repository,
      localProvider: localProvider,
      remoteProvider: remoteProvider
    )
    viewModel.selectedMood = .overwhelmed
    viewModel.noteText = "  The meeting ran long. \n"
    viewModel.failure = .invalidResponse
    viewModel.presentedEntry = CheckInEntry(mood: .low)

    viewModel.saveWithoutReflection()
    await Task.yield()

    let localCallCount = await localProvider.callCount
    let remoteCallCount = await remoteProvider.callCount
    XCTAssertEqual(repository.entries.count, 1)
    XCTAssertEqual(repository.entries.first?.mood, .overwhelmed)
    XCTAssertEqual(repository.entries.first?.noteText, "The meeting ran long.")
    XCTAssertEqual(repository.entries.first?.reflectionStatus, ReflectionStatus.none)
    XCTAssertNil(viewModel.selectedMood)
    XCTAssertEqual(viewModel.noteText, "")
    XCTAssertNil(viewModel.failure)
    XCTAssertTrue(viewModel.presentedEntry === repository.entries.first)
    XCTAssertEqual(localCallCount, 0)
    XCTAssertEqual(remoteCallCount, 0)
  }

  func testUnavailableRemoteReflectionPreservesDraftAndPersistsNothing() async {
    let repository = InMemoryCheckInRepository()
    let remoteProvider = ReflectionProviderSpy(result: .failure(.unavailable))
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .anxious
    viewModel.noteText = "  I am worried about tomorrow.  "

    await viewModel.reflect()

    let remoteCallCount = await remoteProvider.callCount
    XCTAssertTrue(repository.entries.isEmpty)
    XCTAssertEqual(viewModel.selectedMood, .anxious)
    XCTAssertEqual(viewModel.noteText, "  I am worried about tomorrow.  ")
    XCTAssertEqual(viewModel.failure, .unavailable)
    XCTAssertFalse(viewModel.isReflecting)
    XCTAssertEqual(remoteCallCount, 1)
  }

  func testWhitespaceOnlyNoteUsesLocalProviderAndPersistsNilNote() async {
    let repository = InMemoryCheckInRepository()
    let localResult = ReflectionResult.stub(source: .local)
    let localProvider = ReflectionProviderSpy(result: .success(localResult))
    let remoteProvider = ReflectionProviderSpy(result: .success(.stub(source: .ai)))
    let viewModel = CheckInViewModel(
      repository: repository,
      localProvider: localProvider,
      remoteProvider: remoteProvider
    )
    viewModel.selectedMood = .low
    viewModel.noteText = " \n\t "

    await viewModel.reflect()

    let localCallCount = await localProvider.callCount
    let remoteCallCount = await remoteProvider.callCount
    XCTAssertEqual(localCallCount, 1)
    XCTAssertEqual(remoteCallCount, 0)
    XCTAssertNil(repository.entries.first?.noteText)
    XCTAssertEqual(repository.entries.first?.reflectionText, localResult.reflectionText)
    XCTAssertEqual(repository.entries.first?.reflectionSource, .local)
    XCTAssertEqual(repository.entries.first?.reflectionStatus, .completed)
  }

  func testWrittenReflectionTrimsNotePersistsResultAndPresentsEntry() async {
    let repository = InMemoryCheckInRepository()
    let result = ReflectionResult.stub(source: .ai)
    let remoteProvider = ReflectionProviderSpy(result: .success(result))
    let viewModel = CheckInViewModel(
      repository: repository,
      remoteProvider: remoteProvider
    )
    viewModel.selectedMood = .low
    viewModel.noteText = " \n A difficult afternoon. \t"

    await viewModel.reflect()

    let entry = repository.entries.first
    let remoteRequests = await remoteProvider.requests
    XCTAssertEqual(remoteRequests.count, 1)
    XCTAssertEqual(remoteRequests.first?.mood, .low)
    XCTAssertEqual(remoteRequests.first?.noteText, "A difficult afternoon.")
    XCTAssertEqual(entry?.noteText, "A difficult afternoon.")
    XCTAssertEqual(entry?.reflectionText, result.reflectionText)
    XCTAssertEqual(entry?.suggestedActionText, result.suggestedActionText)
    XCTAssertEqual(entry?.reflectionSource, .ai)
    XCTAssertEqual(entry?.reflectionStatus, .completed)
    XCTAssertTrue(viewModel.presentedEntry === entry)
    XCTAssertNil(viewModel.selectedMood)
    XCTAssertEqual(viewModel.noteText, "")
    XCTAssertNil(viewModel.failure)
  }

  func testRepositorySaveFailurePreservesDraftAndDoesNotPresentEntry() async {
    let repository = InMemoryCheckInRepository(saveError: RepositoryTestError.saveFailed)
    let remoteProvider = ReflectionProviderSpy(result: .success(.stub(source: .ai)))
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .overwhelmed
    viewModel.noteText = "  Too much at once.  "

    await viewModel.reflect()

    XCTAssertTrue(repository.entries.isEmpty)
    XCTAssertEqual(viewModel.selectedMood, .overwhelmed)
    XCTAssertEqual(viewModel.noteText, "  Too much at once.  ")
    XCTAssertNil(viewModel.presentedEntry)
    XCTAssertEqual(viewModel.failure, .unavailable)
  }

  func testFailedReflectionClearsPreviouslyPresentedEntryAndPreservesNewDraft() async {
    let repository = InMemoryCheckInRepository()
    let remoteProvider = ReflectionProviderSpy(result: .success(.stub(source: .ai)))
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .bright
    viewModel.noteText = "A good morning."
    await viewModel.reflect()
    XCTAssertNotNil(viewModel.presentedEntry)

    await remoteProvider.setResult(.failure(.invalidResponse))
    viewModel.selectedMood = .anxious
    viewModel.noteText = "  A difficult afternoon.  "

    await viewModel.reflect()

    let remoteCallCount = await remoteProvider.callCount
    XCTAssertNil(viewModel.presentedEntry)
    XCTAssertEqual(viewModel.failure, .invalidResponse)
    XCTAssertEqual(viewModel.selectedMood, .anxious)
    XCTAssertEqual(viewModel.noteText, "  A difficult afternoon.  ")
    XCTAssertEqual(repository.entries.count, 1)
    XCTAssertEqual(remoteCallCount, 2)
  }

  func testReflectIgnoresReentrantCallUntilActiveRequestCompletes() async {
    let repository = InMemoryCheckInRepository()
    let requestStarted = expectation(description: "Reflection request started")
    let remoteProvider = ControllableReflectionProvider { requestStarted.fulfill() }
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .overwhelmed
    viewModel.noteText = "Several things need attention."

    let firstReflection = Task { await viewModel.reflect() }
    await fulfillment(of: [requestStarted], timeout: 1)
    XCTAssertTrue(viewModel.isReflecting)

    await viewModel.reflect()

    let callCountWhileFirstRequestIsActive = await remoteProvider.callCount
    XCTAssertEqual(callCountWhileFirstRequestIsActive, 1)
    XCTAssertTrue(viewModel.isReflecting)

    await remoteProvider.completeFirstRequest(with: .stub(source: .ai))
    await firstReflection.value

    let finalCallCount = await remoteProvider.callCount
    XCTAssertEqual(finalCallCount, 1)
    XCTAssertFalse(viewModel.isReflecting)
    XCTAssertEqual(repository.entries.count, 1)
  }

  func testSuccessfulReflectionPreservesDraftChangedWhileRequestIsActive() async {
    let repository = InMemoryCheckInRepository()
    let requestStarted = expectation(description: "Reflection request started")
    let remoteProvider = ControllableReflectionProvider { requestStarted.fulfill() }
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .anxious
    viewModel.noteText = "  Original concern.  "

    let reflection = Task { await viewModel.reflect() }
    await fulfillment(of: [requestStarted], timeout: 1)
    viewModel.selectedMood = .bright
    viewModel.noteText = "A newer draft"

    await remoteProvider.completeFirstRequest(with: .stub(source: .ai))
    await reflection.value

    XCTAssertEqual(repository.entries.count, 1)
    XCTAssertEqual(repository.entries.first?.mood, .anxious)
    XCTAssertEqual(repository.entries.first?.noteText, "Original concern.")
    XCTAssertTrue(viewModel.presentedEntry === repository.entries.first)
    XCTAssertEqual(viewModel.selectedMood, .bright)
    XCTAssertEqual(viewModel.noteText, "A newer draft")
  }

  func testSaveWithoutReflectionIsNoOpWhileReflectionIsActive() async {
    let repository = InMemoryCheckInRepository()
    let requestStarted = expectation(description: "Reflection request started")
    let remoteProvider = ControllableReflectionProvider { requestStarted.fulfill() }
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .low
    viewModel.noteText = "Keep this active draft"

    let reflection = Task { await viewModel.reflect() }
    await fulfillment(of: [requestStarted], timeout: 1)

    viewModel.saveWithoutReflection()

    XCTAssertTrue(repository.entries.isEmpty)
    XCTAssertEqual(viewModel.selectedMood, .low)
    XCTAssertEqual(viewModel.noteText, "Keep this active draft")
    XCTAssertTrue(viewModel.isReflecting)

    await remoteProvider.completeFirstRequest(with: .stub(source: .ai))
    await reflection.value
    XCTAssertEqual(repository.entries.count, 1)
  }

  func testCancellationAfterProviderReturnsDoesNotPersistOrClearDraft() async {
    let repository = InMemoryCheckInRepository()
    let requestStarted = expectation(description: "Reflection request started")
    let remoteProvider = ControllableReflectionProvider { requestStarted.fulfill() }
    let viewModel = CheckInViewModel(repository: repository, remoteProvider: remoteProvider)
    viewModel.selectedMood = .overwhelmed
    viewModel.noteText = "Keep this cancelled draft"

    let reflection = Task { await viewModel.reflect() }
    await fulfillment(of: [requestStarted], timeout: 1)
    reflection.cancel()

    await remoteProvider.completeFirstRequest(with: .stub(source: .ai))
    await reflection.value

    XCTAssertTrue(repository.entries.isEmpty)
    XCTAssertNil(viewModel.presentedEntry)
    XCTAssertEqual(viewModel.selectedMood, .overwhelmed)
    XCTAssertEqual(viewModel.noteText, "Keep this cancelled draft")
    XCTAssertFalse(viewModel.isReflecting)
    XCTAssertNil(viewModel.failure)
  }

  func testMissingMoodIsNoOp() async {
    let repository = InMemoryCheckInRepository()
    let localProvider = ReflectionProviderSpy(result: .success(.stub(source: .local)))
    let remoteProvider = ReflectionProviderSpy(result: .success(.stub(source: .ai)))
    let viewModel = CheckInViewModel(
      repository: repository,
      localProvider: localProvider,
      remoteProvider: remoteProvider
    )
    viewModel.noteText = "Keep this draft"

    viewModel.saveWithoutReflection()
    await viewModel.reflect()

    let localCallCount = await localProvider.callCount
    let remoteCallCount = await remoteProvider.callCount
    XCTAssertTrue(repository.entries.isEmpty)
    XCTAssertEqual(viewModel.noteText, "Keep this draft")
    XCTAssertEqual(localCallCount, 0)
    XCTAssertEqual(remoteCallCount, 0)
  }
}

@MainActor
private final class InMemoryCheckInRepository: CheckInRepository {
  private(set) var entries: [CheckInEntry] = []
  private let saveError: Error?

  init(saveError: Error? = nil) {
    self.saveError = saveError
  }

  func save(_ entry: CheckInEntry) throws {
    if let saveError {
      throw saveError
    }
    entries.append(entry)
  }

  func deleteAll() throws {
    entries.removeAll()
  }
}

private actor ReflectionProviderSpy: ReflectionProviding {
  enum Result: Sendable {
    case success(ReflectionResult)
    case failure(ReflectionError)
  }

  private(set) var requests: [ReflectionRequest] = []
  private var result: Result

  init(result: Result) {
    self.result = result
  }

  var callCount: Int { requests.count }

  func setResult(_ result: Result) {
    self.result = result
  }

  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    requests.append(request)
    switch result {
    case .success(let reflection):
      return reflection
    case .failure(let error):
      throw error
    }
  }
}

private actor ControllableReflectionProvider: ReflectionProviding {
  private(set) var requests: [ReflectionRequest] = []
  private let onRequest: @Sendable () -> Void
  private var firstRequestContinuation: CheckedContinuation<ReflectionResult, Never>?
  private var queuedResult: ReflectionResult?

  init(onRequest: @escaping @Sendable () -> Void) {
    self.onRequest = onRequest
  }

  var callCount: Int { requests.count }

  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    requests.append(request)
    onRequest()

    guard requests.count == 1 else {
      throw ReflectionError.unavailable
    }

    if let queuedResult {
      self.queuedResult = nil
      return queuedResult
    }

    return await withCheckedContinuation { continuation in
      firstRequestContinuation = continuation
    }
  }

  func completeFirstRequest(with result: ReflectionResult) {
    if let firstRequestContinuation {
      firstRequestContinuation.resume(returning: result)
      self.firstRequestContinuation = nil
    } else {
      queuedResult = result
    }
  }
}

private enum RepositoryTestError: Error {
  case saveFailed
}

private extension ReflectionResult {
  static func stub(source: ReflectionSource) -> ReflectionResult {
    ReflectionResult(
      reflectionText: "A steady reflection.",
      suggestedActionText: "Take one small next step.",
      source: source
    )
  }
}
