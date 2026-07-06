import SwiftData
import SwiftUI

struct EntryDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var entry: CheckInEntry

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption.weight(.semibold))
          .foregroundStyle(DailyBetterStyle.muted)

        Text("\(entry.mood.emoji) \(entry.mood.title)")
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundStyle(DailyBetterStyle.tint)

        if let note = normalized(entry.noteText) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Your note")
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .tracking(1.2)
              .foregroundStyle(DailyBetterStyle.muted)

            Text(note)
              .font(.system(.body, design: .serif))
              .foregroundStyle(DailyBetterStyle.ink)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("reflection.originalNote")
          }
        }

        ReflectionView(
          entry: entry,
          showsMoodSummary: false,
          showsOriginalNote: false,
          showsDoneButton: false,
          showsNavigationChrome: false,
          usesScrollView: false
        )
      }
      .padding(20)
    }
    .navigationTitle("Reflection")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(DailyBetterStyle.top.opacity(0.94), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .dailyBetterBackground()
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

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
