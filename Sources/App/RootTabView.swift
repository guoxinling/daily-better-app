import SwiftData
import SwiftUI

struct RootTabView: View {
  @Environment(\.modelContext) private var modelContext

  @State private var hasBootstrapped = false
  @State private var selectedDestination: AppDestination = .checkIn

  var body: some View {
    destinationPages
      .safeAreaInset(edge: .bottom, spacing: 0) {
        CompactTabBar(selection: $selectedDestination)
          .padding(.bottom, 8)
      }
      .dailyBetterBackground()
      .task {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        AppBootstrapper.bootstrapIfNeeded(in: modelContext)
      }
  }

  private var destinationPages: some View {
    ZStack {
      checkInPage
      destinationPage(.timeline, title: "Timeline", placeholder: "Timeline")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var checkInPage: some View {
    let isSelected = selectedDestination == .checkIn

    return NavigationStack {
      CheckInView()
    }
    .opacity(isSelected ? 1 : 0)
    .allowsHitTesting(isSelected)
    .accessibilityHidden(!isSelected)
  }

  private func destinationPage(
    _ destination: AppDestination,
    title: String,
    placeholder: String
  ) -> some View {
    let isSelected = selectedDestination == destination

    return NavigationStack {
      ZStack {
        DailyBetterBackground()

        Text(placeholder)
          .foregroundStyle(DailyBetterStyle.ink)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle(title)
      .toolbarBackground(.hidden, for: .navigationBar)
    }
    .opacity(isSelected ? 1 : 0)
    .allowsHitTesting(isSelected)
    .accessibilityHidden(!isSelected)
  }
}
