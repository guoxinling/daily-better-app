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
  @State private var confirmsDeleteAll = false

  private let feedbackEmail = "guoxinling_xisu@163.com"
  private let privacyURL = URL(string: "https://guoxinling.github.io/privacy/")!

  private var preferencesModel: AppPreferences? {
    preferences.first
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
    List {
      if let preferencesModel {
        Section("Daily reminder") {
          Toggle("Enable reminder", isOn: reminderEnabledBinding(preferencesModel))

          DatePicker(
            "Reminder time",
            selection: reminderDateBinding(preferencesModel),
            displayedComponents: .hourAndMinute
          )
          .disabled(!preferencesModel.reminderEnabled)
        }

        Section("AI & privacy") {
          NavigationLink("How reflections work") {
            SettingsDetailView(
              title: "How reflections work",
              message: "Mood-only reflections are generated on this device. If you add written text and tap Reflect, the current mood, current note, locale, and request identifier are sent to Daily Better's AI reflection service to generate a one-time response."
            )
          }

          NavigationLink("Storage & privacy") {
            SettingsDetailView(
              title: "Storage & privacy",
              message: "Your Timeline is stored on this device. Daily Better does not require an account for the current check-in flow."
            )
          }
        }

        Section("Your data") {
          NavigationLink("Export timeline") {
            ExportTimelineView()
          }

          Button("Delete all entries", role: .destructive) {
            confirmsDeleteAll = true
          }
        }

        Section("Support") {
          NavigationLink("Safety resources") {
            SafetyResourcesView()
          }

          if let feedbackURL {
            Button("Email support") {
              openURL(feedbackURL) { accepted in
                if !accepted {
                  feedbackUnavailable = true
                }
              }
            }
          }

          Link("Privacy policy", destination: privacyURL)

          Text(feedbackEmail)
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
    .dailyBetterBackground()
    .rootTabBarHidden()
    .alert("Notifications are off", isPresented: $notificationsDenied) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Enable notifications in Settings if you want Daily Better to send your daily reminder.")
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
    .alert("Delete every Timeline entry?", isPresented: $confirmsDeleteAll) {
      Button("Delete all entries", role: .destructive) {
        try? SwiftDataCheckInRepository(context: modelContext).deleteAll()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This cannot be undone. Legacy affirmations are not deleted.")
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
              try? await NotificationManager.schedule(
                ReminderConfiguration(
                  hour: preferencesModel.reminderHour,
                  minute: preferencesModel.reminderMinute
                )
              )
            } else {
              preferencesModel.reminderEnabled = false
              try? modelContext.save()
              notificationsDenied = true
            }
          } else {
            NotificationManager.remove()
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
          try? await NotificationManager.schedule(
            ReminderConfiguration(
              hour: preferencesModel.reminderHour,
              minute: preferencesModel.reminderMinute
            )
          )
        }
      }
    )
  }
}

private struct SettingsDetailView: View {
  let title: String
  let message: String

  var bodyView: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
    .dailyBetterBackground()
  }

  var body: some View {
    bodyView
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ExportTimelineView: View {
  @Query(sort: \CheckInEntry.createdAt) private var entries: [CheckInEntry]
  @Query private var affirmations: [Affirmation]
  @State private var exportURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Your export includes Timeline entries and legacy custom words stored on this device.")
        .font(.body)
        .foregroundStyle(.secondary)

      if let exportURL {
        ShareLink(item: exportURL) {
          Label("Share export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderedProminent)
      } else {
        Button("Prepare export") {
          prepareExport()
        }
        .buttonStyle(.borderedProminent)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
    .dailyBetterBackground()
    .navigationTitle("Export timeline")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func prepareExport() {
    let text = TimelineExportService.render(entries: entries, legacyAffirmations: affirmations)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Daily-Better-Timeline.txt")
    try? text.write(to: url, atomically: true, encoding: .utf8)
    exportURL = url
  }
}

private struct SafetyResourcesView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Daily Better cannot provide crisis care.")
        .font(.headline)

      Text("If you may be in immediate danger, contact local emergency services or a trusted person who can stay with you.")
        .font(.body)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
    .dailyBetterBackground()
    .navigationTitle("Safety resources")
    .navigationBarTitleDisplayMode(.inline)
  }
}
