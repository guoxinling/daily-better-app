import SwiftData
import SwiftUI

struct EntryDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var entry: CheckInEntry

  var body: some View {
    ReflectionView(entry: entry)
      .safeAreaInset(edge: .bottom) {
        HStack(spacing: 12) {
          Button("A little") {
            setHelpfulness(.better)
          }

          Button("Not yet") {
            setHelpfulness(.unchanged)
          }
        }
        .buttonStyle(.bordered)
        .padding()
        .background(.ultraThinMaterial)
      }
  }

  private func setHelpfulness(_ value: Helpfulness) {
    entry.helpfulness = value
    try? modelContext.save()
  }
}
