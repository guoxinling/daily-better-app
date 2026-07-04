import SwiftUI

struct ReflectionView: View {
  @Environment(\.dismiss) private var dismiss

  @ScaledMetric(relativeTo: .title2) private var reflectionFontSize = 25.0
  @ScaledMetric(relativeTo: .body) private var noteFontSize = 17.0
  @ScaledMetric(relativeTo: .headline) private var actionFontSize = 18.0

  let entry: CheckInEntry

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        moodSummary

        if let note = normalized(entry.noteText) {
          Text("\u{201c}\(note)\u{201d}")
            .font(.system(size: noteFontSize, design: .serif))
            .foregroundStyle(DailyBetterStyle.muted)
            .accessibilityLabel("Your note: \(note)")
        }

        if let reflection = normalized(entry.reflectionText) {
          Text(reflection)
            .font(.system(size: reflectionFontSize, weight: .regular, design: .serif))
            .foregroundStyle(DailyBetterStyle.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("reflection.title")
        }

        if let action = normalized(entry.suggestedActionText) {
          VStack(alignment: .leading, spacing: 10) {
            Text("ONE SMALL STEP")
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .tracking(1.2)
              .foregroundStyle(DailyBetterStyle.tint)

            Text(action)
              .font(.system(size: actionFontSize, weight: .medium, design: .rounded))
              .foregroundStyle(DailyBetterStyle.ink)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("reflection.action")
          }
          .padding(18)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .fill(DailyBetterStyle.glass)
              .stroke(DailyBetterStyle.hairline, lineWidth: 1)
          }
        }

        Button("Done") {
          dismiss()
        }
        .font(.system(size: 17, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(DailyBetterStyle.darkAction, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("reflection.done")
      }
      .padding(20)
    }
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Reflection")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(DailyBetterStyle.top.opacity(0.94), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .dailyBetterBackground()
  }

  private var moodSummary: some View {
    HStack(spacing: 14) {
      Text(entry.mood.emoji)
        .font(.system(size: 38))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(entry.mood.title)
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .foregroundStyle(DailyBetterStyle.ink)
        Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(DailyBetterStyle.muted)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
