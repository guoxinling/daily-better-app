import SwiftUI

struct SectionCard<Content: View>: View {
  let title: String
  let subtitle: String?
  let palette: ThemePalette
  @ViewBuilder let content: Content

  init(
    title: String,
    subtitle: String? = nil,
    palette: ThemePalette,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.palette = palette
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 20, weight: .semibold, design: .rounded))
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText)
        }
      }

      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.96), palette.cardBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 10)
    )
  }
}
