import SwiftData
import SwiftUI

struct TimelineView: View {
  @Environment(\.modelContext) private var modelContext

  let refreshToken: Int
  let onCheckIn: () -> Void
  let onSelectEntry: (CheckInEntry) -> Void

  @State private var entries: [CheckInEntry] = []
  @State private var selectedDate = Calendar.current.startOfDay(for: .now)

  private var week: [Date] {
    TimelineCalendar.week(containing: selectedDate)
  }

  private var selectedEntries: [CheckInEntry] {
    TimelineCalendar.entries(entries, on: selectedDate)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        weekNavigation

        Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundStyle(DailyBetterStyle.ink)

        LazyVStack(alignment: .leading, spacing: 28) {
          ForEach(selectedEntries) { entry in
            TimelineEntryRow(entry: entry)
              .contentShape(Rectangle())
              .onTapGesture {
                onSelectEntry(entry)
              }
          }
        }
      }
      .padding(24)
      .padding(.bottom, 90)
    }
    .navigationTitle("Timeline")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .dailyBetterBackground()
    .task {
      reloadEntries()
    }
    .onChange(of: refreshToken) { _, _ in
      reloadEntries()
    }
    .safeAreaInset(edge: .bottom) {
      Button(action: onCheckIn) {
        Label("Check in", systemImage: "plus")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, minHeight: 56)
          .background(DailyBetterStyle.primaryAction, in: Capsule())
      }
      .accessibilityIdentifier("timeline.checkIn")
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
    }
  }

  private var header: some View {
    HStack {
      Text("Timeline")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .tracking(1.1)
        .foregroundStyle(DailyBetterStyle.tint)

      Spacer()

      NavigationLink {
        SettingsView()
      } label: {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(DailyBetterStyle.tint)
          .frame(width: 44, height: 44)
          .background(DailyBetterStyle.glass, in: Circle())
      }
      .accessibilityLabel("Settings")
      .accessibilityIdentifier("settings.open")
    }
  }

  private var weekNavigation: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Button {
          shiftWeek(-1)
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(DailyBetterStyle.ink)
            .frame(width: 36, height: 36)
            .background(DailyBetterStyle.glass, in: Circle())
        }
        .buttonStyle(.plain)

        Spacer()

        Text(weekRangeTitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(DailyBetterStyle.muted)

        Spacer()

        Button {
          shiftWeek(1)
        } label: {
          Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(DailyBetterStyle.ink)
            .frame(width: 36, height: 36)
            .background(DailyBetterStyle.glass, in: Circle())
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 5) {
        ForEach(week, id: \.self) { date in
          Button {
            selectedDate = date
          } label: {
            VStack(spacing: 5) {
              Text(date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(DailyBetterStyle.muted)

              Text(date.formatted(.dateTime.day()))
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(
                  Calendar.current.isDate(date, inSameDayAs: selectedDate) ? DailyBetterStyle.tint : Color.clear,
                  in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .foregroundStyle(
                  Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.white : DailyBetterStyle.ink
                )

              Circle()
                .fill(hasEntries(on: date) ? DailyBetterStyle.tint : Color.clear)
                .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(10)
      .accessibilityElement(children: .contain)
      .background(DailyBetterStyle.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(DailyBetterStyle.hairline, lineWidth: 1)
      }
      .accessibilityIdentifier("timeline.week")
    }
  }

  private var weekRangeTitle: String {
    guard let first = week.first, let last = week.last else { return "" }
    return "\(first.formatted(.dateTime.month().day()))-\(last.formatted(.dateTime.month().day()))"
  }

  private func hasEntries(on date: Date) -> Bool {
    entries.contains { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
  }

  private func shiftWeek(_ amount: Int) {
    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: amount, to: selectedDate) ?? selectedDate
  }

  private func reloadEntries() {
    let descriptor = FetchDescriptor<CheckInEntry>(
      sortBy: [SortDescriptor(\CheckInEntry.createdAt, order: .reverse)]
    )
    entries = (try? modelContext.fetch(descriptor)) ?? []
  }
}
