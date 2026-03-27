import SwiftData
import SwiftUI

struct RootTabView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [AppPreferences]

  @State private var hasBootstrapped = false
  @State private var selectedTab: AppTab = AppLaunchOptions.initialTab

  private var palette: ThemePalette {
    ThemePalette.palette(for: preferences.first?.themeKey ?? ThemeKey.green.rawValue)
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        TodayView()
      }
      .tag(AppTab.today)
      .tabItem {
        Label("Today", systemImage: "sun.max.fill")
      }

      NavigationStack {
        MoodView()
      }
      .tag(AppTab.mood)
      .tabItem {
        Label("Mood", systemImage: "face.smiling.inverse")
      }

      NavigationStack {
        LibraryView()
      }
      .tag(AppTab.library)
      .tabItem {
        Label("Library", systemImage: "books.vertical.fill")
      }

      NavigationStack {
        SettingsView()
      }
      .tag(AppTab.settings)
      .tabItem {
        Label("Settings", systemImage: "slider.horizontal.3")
      }
    }
    .tint(palette.tint)
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(Color.white.opacity(0.82), for: .tabBar)
    .task {
      guard !hasBootstrapped else { return }
      hasBootstrapped = true
      AppBootstrapper.bootstrapIfNeeded(in: modelContext)
    }
  }
}
