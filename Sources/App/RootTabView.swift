import SwiftUI

private struct RootTabBarHiddenPreferenceKey: PreferenceKey {
  static var defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

extension View {
  func rootTabBarHidden(_ hidden: Bool = true) -> some View {
    preference(key: RootTabBarHiddenPreferenceKey.self, value: hidden)
  }

  func onRootTabBarHiddenChange(_ action: @escaping (Bool) -> Void) -> some View {
    onPreferenceChange(RootTabBarHiddenPreferenceKey.self, perform: action)
  }
}

struct RootTabView: View {
  @State private var selectedDestination: AppDestination =
    ProcessInfo.processInfo.environment["DAILYBETTER_SCREEN"] == "timeline" ? .timeline : .checkIn
  @State private var notificationRouteStore = NotificationRouteStore.shared
  @State private var timelineRefreshID = 0
  @State private var pendingTimelineEntryID: UUID?
  @State private var isRootTabBarHidden = false

  var body: some View {
    destinationPages
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if !isRootTabBarHidden {
          CompactTabBar(selection: $selectedDestination)
            .padding(.bottom, 8)
        }
      }
      .dailyBetterBackground()
      .onChange(of: selectedDestination) { _, newValue in
        if newValue == .timeline {
          timelineRefreshID += 1
        }
      }
      .onAppear {
        consumePendingDestination()
      }
      .onChange(of: notificationRouteStore.pendingDestination) { _, _ in
        consumePendingDestination()
      }
  }

  private var destinationPages: some View {
    ZStack {
      checkInPage
      timelinePage
    }
    .onRootTabBarHiddenChange { isRootTabBarHidden = $0 }
    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
  }

  private var checkInPage: some View {
    let isSelected = selectedDestination == .checkIn

    return NavigationStack {
      CheckInView { entry in
        let wasAlreadyTimeline = selectedDestination == .timeline
        pendingTimelineEntryID = entry.id
        selectedDestination = .timeline

        if wasAlreadyTimeline {
          timelineRefreshID += 1
        }
      }
    }
    .opacity(isSelected ? 1 : 0)
    .allowsHitTesting(isSelected)
    .accessibilityHidden(!isSelected)
  }

  private var timelinePage: some View {
    let isSelected = selectedDestination == .timeline

    return NavigationStack {
      TimelineView(
        refreshToken: timelineRefreshID,
        pendingEntryID: pendingTimelineEntryID,
        onPendingEntryConsumed: {
          pendingTimelineEntryID = nil
        }
      )
    }
    .id(timelineRefreshID)
    .opacity(isSelected ? 1 : 0)
    .allowsHitTesting(isSelected)
    .accessibilityHidden(!isSelected)
  }

  private func consumePendingDestination() {
    guard let destination = notificationRouteStore.pendingDestination else {
      return
    }

    selectedDestination = destination
    notificationRouteStore.pendingDestination = nil
  }
}
