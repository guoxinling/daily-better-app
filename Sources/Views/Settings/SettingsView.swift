import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [AppPreferences]

  @State private var feedbackUnavailable = false
  @State private var feedbackCopied = false
  @State private var notificationsDenied = false

  private let feedbackEmail = "guoxinling_xisu@163.com"

  private var preferencesModel: AppPreferences? {
    preferences.first
  }

  private var palette: ThemePalette {
    ThemePalette.palette(for: preferencesModel?.themeKey ?? ThemeKey.green.rawValue)
  }

  private var feedbackURL: URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = feedbackEmail
    components.queryItems = [
      URLQueryItem(name: "subject", value: "Daily Better Feedback")
    ]
    return components.url
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .center, spacing: 16) {
          BrandMarkView(palette: palette, size: 68)

          VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
              .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Shape the tone of your daily check-in.")
              .font(.system(size: 16, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          }

          Spacer(minLength: 0)
        }

        if let preferencesModel {
          SectionCard(title: "Daily reminder", subtitle: "A quiet nudge to open the app.", palette: palette) {
            Toggle("Enable reminder", isOn: reminderEnabledBinding(preferencesModel))
              .tint(palette.tint)

            DatePicker(
              "Reminder time",
              selection: reminderDateBinding(preferencesModel),
              displayedComponents: .hourAndMinute
            )
          }

          SectionCard(title: "Theme", subtitle: "Pick the atmosphere that feels best right now.", palette: palette) {
            HStack(spacing: 10) {
              ForEach(ThemeKey.allCases) { theme in
                Button {
                  preferencesModel.themeKey = theme.rawValue
                  try? modelContext.save()
                } label: {
                  VStack(spacing: 8) {
                    Circle()
                      .fill(ThemePalette.palette(for: theme.rawValue).tint)
                      .frame(width: 28, height: 28)

                    Text(theme.title)
                      .font(.system(size: 12, weight: .semibold, design: .rounded))
                      .multilineTextAlignment(.center)
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)
                  .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                      .fill(preferencesModel.theme == theme ? palette.accent.opacity(0.45) : Color.white.opacity(0.4))
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }

          SectionCard(title: "Text size", subtitle: "Keep your daily card easy on the eyes.", palette: palette) {
            Picker("Text size", selection: textScaleBinding(preferencesModel)) {
              ForEach(TextScaleKey.allCases) { option in
                Text(option.title).tag(option.rawValue)
              }
            }
            .pickerStyle(.segmented)
          }

          SectionCard(title: "Feedback", subtitle: "Questions, ideas, or something not working?", palette: palette) {
            if let feedbackURL {
              Button {
                openURL(feedbackURL) { accepted in
                  if !accepted {
                    feedbackUnavailable = true
                  }
                }
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "envelope.fill")
                    .font(.system(size: 18, weight: .semibold))

                  VStack(alignment: .leading, spacing: 4) {
                    Text("Send Feedback")
                      .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(feedbackEmail)
                      .font(.system(size: 14, weight: .medium, design: .rounded))
                      .foregroundStyle(palette.secondaryText)
                  }

                  Spacer(minLength: 0)

                  Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(palette.tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.accent.opacity(0.55))
                )
              }
              .buttonStyle(.plain)
            }

            Text("Tapping this opens your default mail app with the address filled in.")
              .font(.system(size: 14, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          }

          SectionCard(title: "About Daily Better", subtitle: "A tiny growth companion.", palette: palette) {
            HStack(alignment: .top, spacing: 14) {
              BrandMarkView(palette: palette, size: 54)

              VStack(alignment: .leading, spacing: 8) {
                Text("Read one affirmation, log one emoji, and keep the words that meet you where you are.")
                Text("Everything in this version stays on-device and works without an account.")
                Text("Version 1.0.0")
                  .font(.system(size: 13, weight: .semibold, design: .rounded))
                  .foregroundStyle(palette.secondaryText)
              }
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText)
          }
        }
      }
      .padding(20)
      .padding(.bottom, 20)
    }
    .navigationBarTitleDisplayMode(.inline)
    .dailyBetterBackground(palette)
    .alert("Notifications are off", isPresented: $notificationsDenied) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Enable notifications in Settings if you want Daily Better to remind you each evening.")
    }
    .alert("Can't open Mail right now", isPresented: $feedbackUnavailable) {
      Button("Copy Email") {
        UIPasteboard.general.string = feedbackEmail
        feedbackCopied = true
      }
      Button("OK", role: .cancel) {}
    } message: {
      Text("This device couldn't open a mail app. You can copy the address and email us manually.")
    }
    .alert("Email copied", isPresented: $feedbackCopied) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(feedbackEmail)
    }
  }

  private func reminderEnabledBinding(_ preferencesModel: AppPreferences) -> Binding<Bool> {
    Binding(
      get: { preferencesModel.reminderEnabled },
      set: { newValue in
        preferencesModel.reminderEnabled = newValue
        try? modelContext.save()
        Task {
          if newValue {
            let granted = await NotificationManager.requestAuthorization()
            if granted {
              try? await NotificationManager.scheduleReminder(
                hour: preferencesModel.reminderHour,
                minute: preferencesModel.reminderMinute
              )
            } else {
              preferencesModel.reminderEnabled = false
              try? modelContext.save()
              notificationsDenied = true
            }
          } else {
            NotificationManager.removeReminder()
          }
        }
      }
    )
  }

  private func reminderDateBinding(_ preferencesModel: AppPreferences) -> Binding<Date> {
    Binding(
      get: {
        var components = DateComponents()
        components.hour = preferencesModel.reminderHour
        components.minute = preferencesModel.reminderMinute
        return Calendar.current.date(from: components) ?? .now
      },
      set: { newValue in
        let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
        preferencesModel.reminderHour = components.hour ?? 20
        preferencesModel.reminderMinute = components.minute ?? 30
        try? modelContext.save()

        guard preferencesModel.reminderEnabled else { return }
        Task {
          try? await NotificationManager.scheduleReminder(
            hour: preferencesModel.reminderHour,
            minute: preferencesModel.reminderMinute
          )
        }
      }
    )
  }

  private func textScaleBinding(_ preferencesModel: AppPreferences) -> Binding<String> {
    Binding(
      get: { preferencesModel.textScaleKey },
      set: {
        preferencesModel.textScaleKey = $0
        try? modelContext.save()
      }
    )
  }
}
