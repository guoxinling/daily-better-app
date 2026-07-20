import SwiftUI

struct TimelineEntryRow: View {
  let entry: CheckInEntry

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
        .font(.caption2.monospacedDigit())
        .foregroundStyle(DailyBetterStyle.muted)
        .frame(width: 52, alignment: .trailing)

      Circle()
        .fill(DailyBetterStyle.tint)
        .frame(width: 8, height: 8)
        .padding(.top, 4)

      VStack(alignment: .leading, spacing: 7) {
        Text("\(entry.mood.emoji) \(entry.mood.title)")
          .font(.caption.weight(.bold))
          .foregroundStyle(DailyBetterStyle.tint)

        Text(entry.noteText ?? "Only a feeling was recorded.")
          .font(.system(.body, design: .serif))
          .foregroundStyle(DailyBetterStyle.ink)
          .lineLimit(3)
          .truncationMode(.tail)
          .accessibilityIdentifier("timeline.entry.note.preview")

        if hasSavedReflection {
          Label("Reflection saved", systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(DailyBetterStyle.muted)
            .accessibilityIdentifier("timeline.entry.reflection.badge")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("timeline.entry.row")
  }

  private var hasSavedReflection: Bool {
    normalized(entry.reflectionText) != nil
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
