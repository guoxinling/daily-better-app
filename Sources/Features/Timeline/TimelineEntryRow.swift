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

        if let action = normalized(entry.suggestedActionText) {
          Text(action)
            .font(.caption)
            .foregroundStyle(DailyBetterStyle.muted)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
              Rectangle()
                .fill(DailyBetterStyle.tint.opacity(0.3))
                .frame(width: 2)
            }
        }
      }
    }
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
