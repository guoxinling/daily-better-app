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
  @State private var timelineRefreshID = 0

  var body: some View {
    NavigationStack {
      TimelineView(
        refreshToken: timelineRefreshID,
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
            onEntryCommitted: showDetailAfterComposer
          )
        }
      case .detail(let entry):
        NavigationStack {
          EntryDetailView(
            entry: entry,
            onBack: dismissPresentation,
            onEdit: { showEditorAfterDetail(entry) },
            onDelete: { delete(entry) }
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
    do {
      try SwiftDataCheckInRepository(context: modelContext).delete(entry)
      presentation = nil
      timelineRefreshID += 1
    } catch {
      return
    }
  }

  @MainActor
  private func showDetailAfterComposer(_ entry: CheckInEntry) {
    timelineRefreshID += 1
    presentation = nil
    Task { @MainActor in
      await Task.yield()
      presentation = .detail(entry)
    }
  }
}
