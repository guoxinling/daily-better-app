import SwiftUI

struct BrandMarkView: View {
  let palette: ThemePalette
  var size: CGFloat = 72

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
        .fill(
          LinearGradient(
            colors: [palette.backgroundTop, palette.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            .stroke(Color.white.opacity(0.58), lineWidth: max(1, size * 0.024))
        )
        .shadow(color: palette.tint.opacity(0.18), radius: size * 0.18, x: 0, y: size * 0.12)

      Circle()
        .fill(Color.white.opacity(0.94))
        .frame(width: size * 0.58, height: size * 0.58)
        .overlay(
          Circle()
            .stroke(Color.white.opacity(0.68), lineWidth: max(1, size * 0.02))
        )
        .offset(y: size * 0.02)

      Capsule(style: .continuous)
        .fill(palette.accent.opacity(0.74))
        .frame(width: size * 0.36, height: size * 0.08)
        .offset(y: size * 0.22)

      Image(systemName: "leaf.fill")
        .font(.system(size: size * 0.32, weight: .medium))
        .foregroundStyle(palette.tint)
        .rotationEffect(.degrees(-18))
        .offset(y: -size * 0.02)

      Image(systemName: "sparkles")
        .font(.system(size: size * 0.14, weight: .bold))
        .foregroundStyle(palette.tint.opacity(0.72))
        .offset(x: size * 0.23, y: -size * 0.24)
    }
    .frame(width: size, height: size)
  }
}
