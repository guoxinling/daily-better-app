import SwiftUI

struct TimelineEntryRow: View {
  let entry: CheckInEntry
  private let timelineMarkerTopPadding: CGFloat = 22

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
        .font(.system(size: 13, weight: .medium).monospacedDigit())
        .foregroundStyle(DailyBetterStyle.muted)
        .frame(width: 44, alignment: .trailing)
        .padding(.top, timelineMarkerTopPadding)
        .accessibilityIdentifier("timeline.entry.time")

      timelineRail

      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Text(entry.mood.emoji)
            .font(.system(size: 18))

          Text(entry.mood.title)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(DailyBetterStyle.tint)
        }

        Text(entry.noteText ?? "Only a feeling was recorded.")
          .font(.system(size: 17, design: .serif))
          .lineSpacing(3)
          .foregroundStyle(DailyBetterStyle.ink)
          .lineLimit(3)
          .truncationMode(.tail)
          .accessibilityIdentifier("timeline.entry.note.preview")

        if hasSavedReflection {
          Label("Reflection saved", systemImage: "sparkles")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(DailyBetterStyle.muted)
            .accessibilityIdentifier("timeline.entry.reflection.badge")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 18)
      .background(DailyBetterStyle.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(DailyBetterStyle.hairline, lineWidth: 1)
      }
      .shadow(color: DailyBetterStyle.ink.opacity(0.04), radius: 10, y: 5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("timeline.entry.row")
  }

  private var timelineRail: some View {
    Circle()
      .fill(DailyBetterStyle.tint)
      .frame(width: 10, height: 10)
      .padding(.top, timelineMarkerTopPadding + 3)
      .accessibilityElement()
      .accessibilityLabel("Timeline marker")
      .accessibilityIdentifier("timeline.entry.marker")
    .frame(width: 18)
    .frame(minHeight: 120, alignment: .top)
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

struct EmptyTimelinePromptRow: View {
  private let markerTopPadding: CGFloat = 22
  private let promptTitle = Color(red: 40 / 255, green: 122 / 255, blue: 92 / 255)
  private let promptSubtitle = Color(red: 124 / 255, green: 139 / 255, blue: 132 / 255)

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Color.clear
        .frame(width: 44, height: 1)
        .padding(.top, markerTopPadding)

      timelineStart

      VStack(alignment: .leading, spacing: 6) {
        Text("How are you feeling?")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(promptTitle)

        Text("Take a moment to check in.")
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(promptSubtitle)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 18)
      .background(DailyBetterStyle.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(DailyBetterStyle.hairline, lineWidth: 1)
      }
      .shadow(color: DailyBetterStyle.ink.opacity(0.04), radius: 10, y: 5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("timeline.empty.row")
  }

  private var timelineStart: some View {
    VStack(spacing: 0) {
      Circle()
        .fill(DailyBetterStyle.tint)
        .frame(width: 10, height: 10)
        .accessibilityElement()
        .accessibilityLabel("Timeline start")
        .accessibilityIdentifier("timeline.empty.marker")

      Rectangle()
        .fill(DailyBetterStyle.tint.opacity(0.18))
        .frame(width: 1, height: 42)
    }
    .padding(.top, markerTopPadding + 3)
    .frame(width: 18)
    .frame(minHeight: 96, alignment: .top)
  }
}
