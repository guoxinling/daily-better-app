import SwiftData
import SwiftUI

struct RootTabView: View {
  @Environment(\.modelContext) private var modelContext

  @State private var hasBootstrapped = false
  @State private var selectedDestination: AppDestination = .checkIn

  var body: some View {
    ZStack(alignment: .bottom) {
      Group {
        switch selectedDestination {
        case .checkIn:
          placeholderNavigationStack(title: "Daily Better", placeholder: "Check In")
        case .timeline:
          placeholderNavigationStack(title: "Timeline", placeholder: "Timeline")
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

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

  private func placeholderNavigationStack(title: String, placeholder: String) -> some View {
    NavigationStack {
      Text(placeholder)
        .foregroundStyle(DailyBetterStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .navigationTitle(title)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
  }
}
