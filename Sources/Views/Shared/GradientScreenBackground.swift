import SwiftUI

struct GradientScreenBackground: ViewModifier {
  let palette: ThemePalette

  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          LinearGradient(
            colors: [palette.backgroundTop, palette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          Circle()
            .fill(palette.accent.opacity(0.30))
            .frame(width: 280, height: 280)
            .blur(radius: 18)
            .offset(x: 140, y: -220)

          Circle()
            .fill(palette.tint.opacity(0.12))
            .frame(width: 320, height: 320)
            .blur(radius: 34)
            .offset(x: -160, y: 220)

          RoundedRectangle(cornerRadius: 56, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: 240, height: 240)
            .blur(radius: 48)
            .offset(x: -120, y: -80)
        }
        .ignoresSafeArea()
      )
  }
}

extension View {
  func dailyBetterBackground(_ palette: ThemePalette) -> some View {
    modifier(GradientScreenBackground(palette: palette))
  }
}
