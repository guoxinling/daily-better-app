import SwiftData
import SwiftUI

@main
struct DailyBetterApp: App {
  @UIApplicationDelegateAdaptor(AppNotificationCoordinator.self) private var notificationCoordinator
  private let sharedModelContainer: ModelContainer

  init() {
    do {
      sharedModelContainer = try ModelContainer(
        for: Affirmation.self,
        MoodEntry.self,
        CheckInEntry.self,
        AppPreferences.self
      )
      let bootstrapContext = ModelContext(sharedModelContainer)
      AppBootstrapper.bootstrapIfNeeded(in: bootstrapContext)
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      RootTabView()
    }
    .modelContainer(sharedModelContainer)
  }
}

enum ReflectionProviderFactory {
  static func makeRemoteProvider() -> any ReflectionProviding {
    let arguments = Set(ProcessInfo.processInfo.arguments)
    if arguments.contains("-stub-remote-reflection-success") {
      return StubRemoteReflectionProvider(
        result: ReflectionResult(
          reflectionText: "You sound wound up, not broken. Your mind is still carrying the day forward.",
          suggestedActionText: "Set the phone down and take ten slow breaths before deciding what to do next.",
          source: .ai
        )
      )
    }

    guard
      let baseURL = resolvedBaseURL
    else {
      return UnavailableRemoteReflectionProvider()
    }

    return DeepSeekRemoteReflectionProvider(
      baseURL: baseURL,
      tokenStore: KeychainDeviceTokenStore(),
      appVersion: Bundle.main.dailyBetterAppVersion
    )
  }

  private static var resolvedBaseURL: URL? {
    let environment = ProcessInfo.processInfo.environment
    if let configured = environment["DAILYBETTER_REFLECTION_BASE_URL"], !configured.isEmpty {
      return URL(string: configured)
    }

    return URL(string: "https://daily-better-reflect.vercel.app")
  }
}

private struct StubRemoteReflectionProvider: ReflectionProviding {
  let result: ReflectionResult

  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    result
  }
}

private extension Bundle {
  var dailyBetterAppVersion: String {
    object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
  }
}
