import SwiftUI

enum DailyBetterStyle {
  static let ink = Color(red: 21 / 255, green: 38 / 255, blue: 30 / 255)
  static let muted = Color(red: 104 / 255, green: 122 / 255, blue: 114 / 255)
  static let weakText = Color(red: 138 / 255, green: 153 / 255, blue: 146 / 255)
  static let tint = Color(red: 40 / 255, green: 122 / 255, blue: 92 / 255)
  static let pressed = Color(red: 33 / 255, green: 105 / 255, blue: 79 / 255)
  static let selectedMoodBackground = Color(red: 237 / 255, green: 246 / 255, blue: 240 / 255)
  static let card = Color(red: 1, green: 253 / 255, blue: 252 / 255)
  static let disabled = Color(red: 191 / 255, green: 201 / 255, blue: 196 / 255)
  static let divider = Color(red: 227 / 255, green: 235 / 255, blue: 231 / 255)
  static let keyboardBar = Color(red: 248 / 255, green: 250 / 255, blue: 248 / 255).opacity(0.96)
  static let primaryAction = LinearGradient(
    colors: [
      Color(red: 40 / 255, green: 122 / 255, blue: 92 / 255),
      Color(red: 40 / 255, green: 122 / 255, blue: 92 / 255)
    ],
    startPoint: .leading,
    endPoint: .trailing
  )
  static let darkAction = pressed
  static let top = Color(red: 245 / 255, green: 249 / 255, blue: 246 / 255)
  static let bottom = Color(red: 245 / 255, green: 249 / 255, blue: 246 / 255)
  static let glass = card.opacity(0.78)
  static let hairline = Color(red: 221 / 255, green: 231 / 255, blue: 225 / 255)
}
