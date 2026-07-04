import SwiftData
import SwiftUI

struct RootTabView: View {
  @State private var selectedDestination: AppDestination = .checkIn
  @State private var timelineRefreshID = 0

  var body: some View {
    destinationPages
      .safeAreaInset(edge: .bottom, spacing: 0) {
        CompactTabBar(selection: $selectedDestination)
          .padding(.bottom, 8)
      }
      .dailyBetterBackground()
      .onChange(of: selectedDestination) { _, newValue in
        if newValue == .timeline {
          timelineRefreshID += 1
        }
      }
  }

  private var destinationPages: some View {
    ZStack {
      checkInPage
      timelinePage
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

  private var timelinePage: some View {
    let isSelected = selectedDestination == .timeline

    return NavigationStack {
      TimelineView(refreshToken: timelineRefreshID)
    }
    .id(timelineRefreshID)
    .opacity(isSelected ? 1 : 0)
    .allowsHitTesting(isSelected)
    .accessibilityHidden(!isSelected)
  }
}
