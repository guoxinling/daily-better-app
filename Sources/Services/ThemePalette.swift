import SwiftUI

struct ThemePalette {
  let tint: Color
  let accent: Color
  let backgroundTop: Color
  let backgroundBottom: Color
  let cardBackground: Color
  let border: Color
  let secondaryText: Color

  static func palette(for themeKey: String) -> ThemePalette {
    switch ThemeKey(rawValue: themeKey) ?? .green {
    case .green:
      return ThemePalette(
        tint: Color(red: 0.18, green: 0.47, blue: 0.35),
        accent: Color(red: 0.60, green: 0.83, blue: 0.72),
        backgroundTop: Color(red: 0.94, green: 0.98, blue: 0.95),
        backgroundBottom: Color(red: 0.87, green: 0.94, blue: 0.89),
        cardBackground: Color.white.opacity(0.9),
        border: Color.white.opacity(0.75),
        secondaryText: Color(red: 0.26, green: 0.35, blue: 0.30)
      )
    case .sand:
      return ThemePalette(
        tint: Color(red: 0.60, green: 0.42, blue: 0.23),
        accent: Color(red: 0.93, green: 0.82, blue: 0.63),
        backgroundTop: Color(red: 0.98, green: 0.95, blue: 0.90),
        backgroundBottom: Color(red: 0.94, green: 0.88, blue: 0.78),
        cardBackground: Color.white.opacity(0.88),
        border: Color.white.opacity(0.70),
        secondaryText: Color(red: 0.40, green: 0.31, blue: 0.20)
      )
    case .sky:
      return ThemePalette(
        tint: Color(red: 0.16, green: 0.39, blue: 0.63),
        accent: Color(red: 0.64, green: 0.84, blue: 0.98),
        backgroundTop: Color(red: 0.93, green: 0.97, blue: 1.0),
        backgroundBottom: Color(red: 0.83, green: 0.90, blue: 0.98),
        cardBackground: Color.white.opacity(0.90),
        border: Color.white.opacity(0.72),
        secondaryText: Color(red: 0.21, green: 0.29, blue: 0.40)
      )
    }
  }
}
