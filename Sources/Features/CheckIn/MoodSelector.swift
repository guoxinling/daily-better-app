import SwiftUI

struct MoodSelector: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var selection: CheckInMood?

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8),
      count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
    )
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8) {
      ForEach(CheckInMood.allCases) { mood in
        moodButton(mood)
      }
    }
  }

  private func moodButton(_ mood: CheckInMood) -> some View {
    let isSelected = selection == mood

    return Button {
      selection = mood
    } label: {
      VStack(spacing: 6) {
        Text(mood.emoji)
          .font(.system(size: 25))

        Text(mood.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .foregroundStyle(DailyBetterStyle.ink)
      .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 72)
      .background {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(isSelected ? DailyBetterStyle.tint.opacity(0.16) : DailyBetterStyle.glass)
          .stroke(
            isSelected ? DailyBetterStyle.tint : DailyBetterStyle.hairline,
            lineWidth: isSelected ? 2 : 1
          )
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(mood.emoji) \(mood.title)")
    .accessibilityIdentifier("mood.\(mood.rawValue)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
