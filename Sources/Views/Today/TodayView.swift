import SwiftData
import SwiftUI

struct TodayView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Affirmation.createdAt) private var affirmations: [Affirmation]
  @Query(sort: \MoodEntry.date, order: .reverse) private var moodEntries: [MoodEntry]
  @Query private var preferences: [AppPreferences]

  @AppStorage("dailybetter.today.key") private var storedDayKey = ""
  @AppStorage("dailybetter.today.offset") private var storedOffset = 0

  @State private var showingAddAffirmation = false

  private var palette: ThemePalette {
    ThemePalette.palette(for: preferences.first?.themeKey ?? ThemeKey.green.rawValue)
  }

  private var textScale: TextScaleKey {
    preferences.first?.textScale ?? .medium
  }

  private var todayMood: MoodEntry? {
    moodEntries.first(where: { Calendar.current.isDateInToday($0.date) })
  }

  private var currentAffirmation: Affirmation? {
    TodayAffirmationSelection.currentAffirmation(from: affirmations, offset: storedOffset)
  }

  private var savedCount: Int {
    affirmations.filter(\.isFavorite).count
  }

  private var weeklyMoodCount: Int {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: .now)
    guard let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
      return moodEntries.count
    }
    return moodEntries.filter { $0.date >= start }.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .center, spacing: 16) {
          BrandMarkView(palette: palette, size: 76)

          VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
              .font(.system(size: 14, weight: .semibold, design: .rounded))
              .foregroundStyle(palette.secondaryText)
            Text("Daily Better")
              .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("A softer place to notice your growth.")
              .font(.system(size: 16, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          }

          Spacer(minLength: 0)
        }

        HStack(spacing: 12) {
          insightCard(title: "Saved", value: "\(savedCount)", subtitle: "Words you kept")
          insightCard(title: "This week", value: "\(weeklyMoodCount)/7", subtitle: "Mood check-ins")
        }

        if let currentAffirmation {
          Text("Today's line")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(palette.secondaryText)

          AffirmationCardView(
            text: currentAffirmation.text,
            category: currentAffirmation.category,
            palette: palette,
            textScale: textScale
          )

          HStack(spacing: 12) {
            Button {
              currentAffirmation.isFavorite.toggle()
              try? modelContext.save()
            } label: {
              Label(
                currentAffirmation.isFavorite ? "Saved" : "Favorite",
                systemImage: currentAffirmation.isFavorite ? "heart.fill" : "heart"
              )
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.tint)

            Button {
              storedOffset += 1
            } label: {
              Label("Next", systemImage: "arrow.right.circle")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(palette.tint)
          }
        } else {
          SectionCard(title: "No affirmations yet", subtitle: "Seed data will appear on first launch.", palette: palette) {
            EmptyView()
          }
        }

        SectionCard(
          title: "How do you feel today?",
          subtitle: todayMood?.moodKind.supportText ?? "Pick the emoji that feels closest right now.",
          palette: palette
        ) {
          MoodPickerView(selectedMood: todayMood?.moodKind, palette: palette) { mood in
            saveMood(mood)
          }

          if let todayMood {
            Text("Today's mood: \(todayMood.emoji) \(todayMood.label)")
              .font(.system(size: 14, weight: .semibold, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          }
        }

        SectionCard(
          title: "Make it personal",
          subtitle: "Write your own sentence for the days you need something more specific.",
          palette: palette
        ) {
          Button {
            showingAddAffirmation = true
          } label: {
            Label("Write my own affirmation", systemImage: "square.and.pencil")
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(palette.tint)
        }
      }
      .padding(20)
      .padding(.bottom, 20)
    }
    .navigationBarTitleDisplayMode(.inline)
    .dailyBetterBackground(palette)
    .sheet(isPresented: $showingAddAffirmation) {
      NavigationStack {
        AddAffirmationView()
      }
    }
    .onAppear {
      let todayKey = TodayAffirmationSelection.dayKey()
      if storedDayKey != todayKey {
        storedDayKey = todayKey
        storedOffset = 0
      }
    }
  }

  private func insightCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .tracking(1.2)
        .foregroundStyle(palette.secondaryText)
      Text(value)
        .font(.system(size: 26, weight: .bold, design: .rounded))
      Text(subtitle)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(palette.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color.white.opacity(0.62))
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    )
  }

  private func saveMood(_ mood: MoodKind) {
    if let todayMood {
      todayMood.emoji = mood.rawValue
      todayMood.label = mood.label
    } else {
      modelContext.insert(MoodEntry(date: .now, mood: mood))
    }
    try? modelContext.save()
  }
}
