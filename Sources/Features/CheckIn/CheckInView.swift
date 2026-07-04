import SwiftData
import SwiftUI

struct CheckInView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext

  @ScaledMetric(relativeTo: .largeTitle) private var headingFontSize = 34.0
  @ScaledMetric(relativeTo: .title3) private var noteFontSize = 21.0
  @State private var viewModel: CheckInViewModel?

  var body: some View {
    Group {
      if let viewModel {
        checkInContent(viewModel)
      } else {
        ProgressView("Preparing your check-in")
          .foregroundStyle(DailyBetterStyle.muted)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationTitle("Daily Better")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .dailyBetterBackground()
    .task {
      guard viewModel == nil else { return }
      viewModel = CheckInViewModel(
        repository: SwiftDataCheckInRepository(context: modelContext),
        remoteProvider: UnavailableRemoteReflectionProvider()
      )
    }
  }

  private func checkInContent(_ viewModel: CheckInViewModel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: contentSpacing) {
        header

        VStack(alignment: .leading, spacing: 8) {
          Text("Check In")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(DailyBetterStyle.tint)

          Text("How are you?")
            .font(.system(size: headingSize, weight: .bold, design: .rounded))
            .foregroundStyle(DailyBetterStyle.ink)
        }

        MoodSelector(selection: moodBinding(viewModel))

        if let selectedMood = viewModel.selectedMood, !dynamicTypeSize.isAccessibilitySize {
          Text(selectedMood.title)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(DailyBetterStyle.tint)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }

        noteEditor(viewModel)

        VStack(spacing: 12) {
          Button {
            Task { await viewModel.reflect() }
          } label: {
            Group {
              if viewModel.isReflecting {
                HStack(spacing: 10) {
                  ProgressView()
                    .tint(.white)
                  Text("Reflecting\u{2026}")
                }
              } else {
                Text("Reflect")
              }
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(DailyBetterStyle.darkAction, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(viewModel.selectedMood == nil || viewModel.isReflecting)
          .opacity(viewModel.selectedMood == nil ? 0.5 : 1)
          .accessibilityIdentifier("checkIn.reflect")

          Button("Save without reflection") {
            viewModel.saveWithoutReflection()
          }
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .foregroundStyle(DailyBetterStyle.tint)
          .frame(maxWidth: .infinity, minHeight: 48)
          .disabled(viewModel.selectedMood == nil || viewModel.isReflecting)
          .accessibilityIdentifier("checkIn.saveOnly")
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, contentBottomPadding)
    }
    .scrollDismissesKeyboard(.interactively)
    .sheet(item: presentedEntryBinding(viewModel)) { entry in
      NavigationStack {
        ReflectionView(entry: entry)
      }
    }
    .alert("Couldn't reflect right now", isPresented: failureBinding(viewModel)) {
      Button("Save without reflection") {
        viewModel.saveWithoutReflection()
      }
      Button("Try again") {
        Task { await viewModel.reflect() }
      }
      Button("Cancel", role: .cancel) {
        viewModel.failure = nil
      }
    } message: {
      Text("Your entry is still here.")
    }
  }

  private var header: some View {
    HStack {
      Text("Daily Better")
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(DailyBetterStyle.ink)

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

  private func noteEditor(_ viewModel: CheckInViewModel) -> some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(DailyBetterStyle.glass)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)

      if viewModel.noteText.isEmpty {
        Text("What's on your mind?")
          .font(.system(size: noteFontSize, design: .serif))
          .foregroundStyle(DailyBetterStyle.muted.opacity(0.8))
          .padding(.horizontal, 17)
          .padding(.vertical, 18)
          .allowsHitTesting(false)
      }

      TextEditor(text: noteBinding(viewModel))
        .font(.system(size: noteFontSize, design: .serif))
        .foregroundStyle(DailyBetterStyle.ink)
        .scrollContentBackground(.hidden)
        .padding(10)
        .frame(minHeight: noteEditorMinHeight)
        .accessibilityLabel("What's on your mind?")
        .accessibilityIdentifier("checkIn.note")
    }
    .frame(minHeight: noteEditorMinHeight)
  }

  private var contentSpacing: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 18 : 24
  }

  private var headingSize: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? min(headingFontSize, 28) : headingFontSize
  }

  private var noteEditorMinHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 128 : 190
  }

  private var contentBottomPadding: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 12 : 20
  }

  private func moodBinding(_ viewModel: CheckInViewModel) -> Binding<CheckInMood?> {
    Binding(
      get: { viewModel.selectedMood },
      set: { viewModel.selectedMood = $0 }
    )
  }

  private func noteBinding(_ viewModel: CheckInViewModel) -> Binding<String> {
    Binding(
      get: { viewModel.noteText },
      set: { viewModel.noteText = $0 }
    )
  }

  private func presentedEntryBinding(_ viewModel: CheckInViewModel) -> Binding<CheckInEntry?> {
    Binding(
      get: { viewModel.presentedEntry },
      set: { viewModel.presentedEntry = $0 }
    )
  }

  private func failureBinding(_ viewModel: CheckInViewModel) -> Binding<Bool> {
    Binding(
      get: { viewModel.failure != nil },
      set: { isPresented in
        if !isPresented {
          viewModel.failure = nil
        }
      }
    )
  }
}
