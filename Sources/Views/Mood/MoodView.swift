import SwiftData
import SwiftUI

struct MoodView: View {
  @Query(sort: \MoodEntry.date, order: .reverse) private var moodEntries: [MoodEntry]
  @Query private var preferences: [AppPreferences]

  private var palette: ThemePalette {
    ThemePalette.palette(for: preferences.first?.themeKey ?? ThemeKey.green.rawValue)
  }

  private var recentWeekDates: [Date] {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: .now)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }.reversed()
  }

  private var todayMood: MoodEntry? {
    moodEntry(for: .now)
  }

  private var weeklyLoggedCount: Int {
    recentWeekDates.compactMap(moodEntry(for:)).count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Mood")
            .font(.system(size: 34, weight: .bold, design: .rounded))
          Text("A gentle place to look back on how the week has felt.")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText)
        }

        SectionCard(
          title: "Today",
          subtitle: todayMood == nil ? "Record today's mood from the Today tab." : "Your check-in lives on the Today tab. Here you can simply look back.",
          palette: palette
        ) {
          if let todayMood {
            HStack(spacing: 14) {
              Text(todayMood.emoji)
                .font(.system(size: 44))

              VStack(alignment: .leading, spacing: 4) {
                Text(todayMood.label)
                  .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(todayMood.moodKind.supportText)
                  .font(.system(size: 14, weight: .medium, design: .rounded))
                  .foregroundStyle(palette.secondaryText)
              }

              Spacer()
            }
          } else {
            Text("No mood recorded yet for today.")
              .font(.system(size: 15, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          }
        }

        SectionCard(
          title: "This week",
          subtitle: "A simple snapshot of your last seven days. Logged \(weeklyLoggedCount) of 7 days.",
          palette: palette
        ) {
          HStack(spacing: 10) {
            ForEach(recentWeekDates, id: \.self) { date in
              let entry = moodEntry(for: date)
              VStack(spacing: 8) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                  .font(.system(size: 12, weight: .semibold, design: .rounded))
                  .foregroundStyle(palette.secondaryText)
                Text(entry?.emoji ?? "—")
                  .font(.system(size: 28))
                Text(date.formatted(.dateTime.day()))
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(palette.secondaryText)
              }
              .frame(maxWidth: .infinity)
            }
          }
        }

        SectionCard(title: "History", subtitle: moodEntries.isEmpty ? "Once you record a mood, it will show up here." : "Your newest check-ins first.", palette: palette) {
          if moodEntries.isEmpty {
            Text("No mood entries yet.")
              .font(.system(size: 15, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          } else {
            LazyVStack(spacing: 12) {
              ForEach(moodEntries) { entry in
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(.dateTime.month().day().weekday(.wide)))
                      .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(entry.moodKind.supportText)
                      .font(.system(size: 13, weight: .medium, design: .rounded))
                      .foregroundStyle(palette.secondaryText)
                  }
                  Spacer()
                  Text(entry.emoji)
                    .font(.system(size: 30))
                }
                .padding(16)
                .background(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                )
              }
            }
          }
        }
      }
      .padding(20)
      .padding(.bottom, 20)
    }
    .navigationBarTitleDisplayMode(.inline)
    .dailyBetterBackground(palette)
  }

  private func moodEntry(for date: Date) -> MoodEntry? {
    moodEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
  }
}
