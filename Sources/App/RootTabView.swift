import SwiftData
import SwiftUI

extension View {
  func rootTabBarHidden(_ hidden: Bool = true) -> some View {
    self
  }
}

private enum RootPresentation: Identifiable {
  case newEntry(EntryComposerMode)
  case detail(CheckInEntry)

  var id: String {
    switch self {
    case .newEntry:
      "new-entry"
    case .detail(let entry):
      "detail-\(entry.id.uuidString)"
    }
  }
}

struct RootTabView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var notificationRouteStore = NotificationRouteStore.shared
  @State private var presentation: RootPresentation?
  @State private var timelineRefreshRequest = TimelineRefreshRequest(
    sequence: 0,
    targetDate: .now
  )

  var body: some View {
    NavigationStack {
      TimelineView(
        refreshRequest: timelineRefreshRequest,
        onCheckIn: presentNewEntry,
        onSelectEntry: { entry in
          presentation = .detail(entry)
        }
      )
    }
    .fullScreenCover(item: $presentation) { presentation in
      switch presentation {
      case .newEntry(let mode):
        NavigationStack {
          CheckInView(
            mode: mode,
            onCancel: dismissPresentation,
            onEntryCommitted: { entry in
              showTimelineAfterComposer(entry, mode: mode)
            }
          )
        }
      case .detail(let entry):
        NavigationStack {
          EntryDetailView(
            entry: entry,
            onBack: dismissPresentation,
            onEdit: { showEditorAfterDetail(entry) },
            onDelete: { delete(entry) },
            onSetHelpfulness: { setHelpfulness($0, for: entry) }
          )
        }
      }
    }
    .onAppear(perform: consumePendingDestination)
    .onChange(of: notificationRouteStore.pendingDestination) { _, _ in
      consumePendingDestination()
    }
  }

  private func consumePendingDestination() {
    guard notificationRouteStore.pendingDestination == .newEntry else {
      return
    }

    presentNewEntry()
    notificationRouteStore.pendingDestination = nil
  }

  private func presentNewEntry() {
    presentation = .newEntry(.create(createdAt: .now))
  }

  private func dismissPresentation() {
    presentation = nil
  }

  private func showEditorAfterDetail(_ entry: CheckInEntry) {
    presentation = nil
    Task { @MainActor in
      await Task.yield()
      presentation = .newEntry(.edit(entry))
    }
  }

  private func delete(_ entry: CheckInEntry) {
    let entryDate = entry.createdAt
    do {
      try SwiftDataCheckInRepository(context: modelContext).delete(entry)
      presentation = nil
      refreshTimeline(selecting: entryDate)
    } catch {
      return
    }
  }

  private func setHelpfulness(_ helpfulness: Helpfulness, for entry: CheckInEntry) {
    try? SwiftDataCheckInRepository(context: modelContext)
      .setHelpfulness(helpfulness, for: entry)
  }

  @MainActor
  private func showTimelineAfterComposer(_ entry: CheckInEntry, mode: EntryComposerMode) {
    switch mode {
    case .create:
      refreshTimeline(selecting: .now)
    case .edit:
      refreshTimeline(selecting: entry.createdAt)
    }
    presentation = nil
  }

  private func refreshTimeline(selecting targetDate: Date) {
    timelineRefreshRequest = TimelineRefreshRequest(
      sequence: timelineRefreshRequest.sequence + 1,
      targetDate: targetDate
    )
  }
}
