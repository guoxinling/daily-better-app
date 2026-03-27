import SwiftData
import SwiftUI

struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Affirmation.createdAt) private var affirmations: [Affirmation]
  @Query private var preferences: [AppPreferences]

  @State private var selectedSection: LibrarySection = .browse
  @State private var selectedCategory: AffirmationCategory = .growth
  @State private var showingAddAffirmation = false

  private var palette: ThemePalette {
    ThemePalette.palette(for: preferences.first?.themeKey ?? ThemeKey.green.rawValue)
  }

  private var activeAffirmations: [Affirmation] {
    let sorted = affirmations.sorted { $0.createdAt > $1.createdAt }
    switch selectedSection {
    case .browse:
      return sorted.filter { $0.category == selectedCategory }
    case .favorites:
      return sorted.filter(\.isFavorite)
    case .mine:
      return sorted.filter(\.isCustom)
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Library")
            .font(.system(size: 34, weight: .bold, design: .rounded))
          Text("Browse your encouragement, save what helps, and write your own.")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText)
          Text("\(affirmations.count) lines ready for the days you need them.")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
              Capsule(style: .continuous)
                .fill(Color.white.opacity(0.58))
            )
        }

        Picker("Section", selection: $selectedSection) {
          ForEach(LibrarySection.allCases) { section in
            Text(section.title).tag(section)
          }
        }
        .pickerStyle(.segmented)

        if selectedSection == .browse {
          categoryChips
        }

        SectionCard(
          title: sectionTitle,
          subtitle: sectionSubtitle,
          palette: palette
        ) {
          if activeAffirmations.isEmpty {
            Text(emptyStateText)
              .font(.system(size: 15, weight: .medium, design: .rounded))
              .foregroundStyle(palette.secondaryText)
          } else {
            LazyVStack(spacing: 14) {
              ForEach(activeAffirmations) { affirmation in
                VStack(alignment: .leading, spacing: 12) {
                  Text(affirmation.category.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)

                  Text(affirmation.text)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                  HStack {
                    Button {
                      affirmation.isFavorite.toggle()
                      try? modelContext.save()
                    } label: {
                      Label(
                        affirmation.isFavorite ? "Saved" : "Save",
                        systemImage: affirmation.isFavorite ? "heart.fill" : "heart"
                      )
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.tint)

                    if affirmation.isCustom {
                      Text("Your words")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                          Capsule(style: .continuous)
                            .fill(palette.accent.opacity(0.35))
                        )
                    }

                    Spacer()
                  }
                }
                .padding(18)
                .background(
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.58))
                )
              }
            }
          }
        }
      }
      .padding(20)
      .padding(.bottom, 20)
    }
    .navigationTitle("Library")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showingAddAffirmation = true
        } label: {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAddAffirmation) {
      NavigationStack {
        AddAffirmationView()
      }
    }
    .dailyBetterBackground(palette)
  }

  private var categoryChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(AffirmationCategory.allCases) { category in
          Button {
            selectedCategory = category
          } label: {
            Text(category.title)
              .font(.system(size: 14, weight: .semibold, design: .rounded))
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(
                Capsule(style: .continuous)
                  .fill(selectedCategory == category ? palette.tint : palette.cardBackground)
                  .stroke(selectedCategory == category ? palette.tint : palette.border, lineWidth: 1)
              )
              .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var sectionTitle: String {
    switch selectedSection {
    case .browse:
      selectedCategory.title
    case .favorites:
      "Favorites"
    case .mine:
      "My affirmations"
    }
  }

  private var sectionSubtitle: String {
    switch selectedSection {
    case .browse:
      "A small library of words for the feeling you need most."
    case .favorites:
      "The lines that have already helped you once."
    case .mine:
      "Your own reminders, written in your own voice."
    }
  }

  private var emptyStateText: String {
    switch selectedSection {
    case .browse:
      "No affirmations in this category yet."
    case .favorites:
      "Save a few affirmations and they will appear here."
    case .mine:
      "Write your first custom affirmation to make the app feel more personal."
    }
  }
}
