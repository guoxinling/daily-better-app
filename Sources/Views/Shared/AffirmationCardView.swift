import SwiftUI

struct AffirmationCardView: View {
  let text: String
  let category: AffirmationCategory
  let palette: ThemePalette
  let textScale: TextScaleKey

  var body: some View {
    ZStack(alignment: .topTrailing) {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.98), palette.cardBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 10)

      Image(systemName: "quote.opening")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(palette.accent.opacity(0.48))
        .padding(22)

      VStack(alignment: .leading, spacing: 18) {
        Text(category.title.uppercased())
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .tracking(1.4)
          .foregroundStyle(palette.secondaryText)

        Text(text)
          .font(.system(size: 28 * textScale.multiplier, weight: .semibold, design: .rounded))
          .foregroundStyle(Color.primary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(24)
    }
  }
}
