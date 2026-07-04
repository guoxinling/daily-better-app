import SwiftUI

struct MoodSelector: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var selection: CheckInMood?

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        adaptiveGrid
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) {
            moodButtons
          }

          adaptiveGrid
        }
      }
    }
  }

  private var adaptiveGrid: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
      spacing: 8
    ) {
      moodButtons
    }
  }

  @ViewBuilder
  private var moodButtons: some View {
    ForEach(CheckInMood.allCases) { mood in
      let isSelected = selection == mood

      Button {
        selection = mood
      } label: {
        Text(mood.emoji)
          .font(.system(size: 25))
          .frame(width: 48, height: 48)
          .background {
            Circle()
              .fill(isSelected ? DailyBetterStyle.tint.opacity(0.16) : DailyBetterStyle.glass)
          }
          .overlay {
            Circle()
              .stroke(
                isSelected ? DailyBetterStyle.tint : DailyBetterStyle.hairline,
                lineWidth: isSelected ? 2 : 1
              )
          }
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(mood.title)
      .accessibilityIdentifier("mood.\(mood.rawValue)")
      .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
  }
}
