import SwiftUI

struct MoodPickerView: View {
  let selectedMood: MoodKind?
  let palette: ThemePalette
  let onSelect: (MoodKind) -> Void

  var body: some View {
    HStack(spacing: 10) {
      ForEach(MoodKind.allCases) { mood in
        Button {
          onSelect(mood)
        } label: {
          VStack(spacing: 6) {
            Text(mood.rawValue)
              .font(.system(size: 28))
            Text(mood.label)
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(selectedMood == mood ? Color.white.opacity(0.92) : palette.secondaryText)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(selectedMood == mood ? palette.tint : palette.cardBackground)
              .stroke(selectedMood == mood ? palette.tint : palette.border, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}
