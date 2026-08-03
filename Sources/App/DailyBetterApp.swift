import SwiftData
import SwiftUI

@main
struct DailyBetterApp: App {
  @UIApplicationDelegateAdaptor(AppNotificationCoordinator.self) private var notificationCoordinator
  private let sharedModelContainer: ModelContainer
  private let bootstrapErrorMessage: String?

  init() {
    do {
      let container = try ModelContainer(
        for: Affirmation.self,
        MoodEntry.self,
        CheckInEntry.self,
        EntryAttachment.self,
        AppPreferences.self
      )
      sharedModelContainer = container

      do {
        let bootstrapContext = ModelContext(container)
        try AppBootstrapper.bootstrapIfNeeded(in: bootstrapContext)
        bootstrapErrorMessage = nil
      } catch {
        bootstrapErrorMessage = error.localizedDescription
      }
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      BootstrapGate(initialErrorMessage: bootstrapErrorMessage)
    }
    .modelContainer(sharedModelContainer)
  }
}

private struct BootstrapGate: View {
  @Environment(\.modelContext) private var modelContext
  @State private var errorMessage: String?

  init(initialErrorMessage: String?) {
    _errorMessage = State(initialValue: initialErrorMessage)
  }

  var body: some View {
    if errorMessage == nil {
      RootTabView()
    } else {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(DailyBetterStyle.tint)

        Text("Couldn't open your journal")
          .font(.system(size: 24, weight: .bold, design: .rounded))

        Text("Your existing entries have not been changed. Try opening them again.")
          .multilineTextAlignment(.center)
          .foregroundStyle(DailyBetterStyle.muted)

        Button("Try again", action: retryBootstrap)
          .buttonStyle(.borderedProminent)
      }
      .padding(32)
      .dailyBetterBackground()
      .accessibilityIdentifier("bootstrap.failure")
    }
  }

  private func retryBootstrap() {
    do {
      try AppBootstrapper.bootstrapIfNeeded(in: modelContext)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
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

  static func resolveBaseURL(
    environment: [String: String],
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) -> URL? {
    if let configured = environment["DAILYBETTER_REFLECTION_BASE_URL"], !configured.isEmpty,
       let configuredURL = URL(string: configured) {
      if configuredURL.isLocalReflectionBackend,
         !arguments.contains("-allow-local-reflection-backend") {
        return productionBaseURL
      }

      return configuredURL
    }

    return productionBaseURL
  }

  private static var resolvedBaseURL: URL? {
    resolveBaseURL(environment: ProcessInfo.processInfo.environment)
  }

  private static let productionBaseURL = URL(string: "https://daily-better-alpha.vercel.app")
}

private extension URL {
  var isLocalReflectionBackend: Bool {
    guard scheme == "http" else {
      return false
    }

    return host == "127.0.0.1" || host == "localhost"
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
