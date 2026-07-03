import SwiftUI

struct DailyBetterBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [DailyBetterStyle.top, DailyBetterStyle.bottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [
          Color(red: 0.74, green: 0.88, blue: 0.81).opacity(0.55),
          .clear,
        ],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 260
      )

      Canvas { context, size in
        var dots = Path()

        for x in stride(from: 4.0, through: size.width, by: 8.0) {
          for y in stride(from: 4.0, through: size.height, by: 8.0) {
            dots.addRect(CGRect(x: x, y: y, width: 0.8, height: 0.8))
          }
        }

        context.fill(dots, with: .color(DailyBetterStyle.tint.opacity(0.06)))
      }
      .allowsHitTesting(false)
    }
    .ignoresSafeArea()
  }
}

extension View {
  func dailyBetterBackground() -> some View {
    background {
      DailyBetterBackground()
    }
  }
}
