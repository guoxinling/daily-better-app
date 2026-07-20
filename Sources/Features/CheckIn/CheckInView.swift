import SwiftData
import SwiftUI
import UIKit

struct CheckInView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext

  @ScaledMetric(relativeTo: .largeTitle) private var headingFontSize = 34.0
  @ScaledMetric(relativeTo: .title3) private var noteFontSize = 21.0
  @FocusState private var isNoteFocused: Bool
  @State private var confirmsDiscard = false
  @State private var viewModel: CheckInViewModel?
  private let mode: EntryComposerMode
  private let remoteProvider: any ReflectionProviding
  private let onCancel: () -> Void
  private let onEntryCommitted: (CheckInEntry) -> Void

  init(
    mode: EntryComposerMode = .create(createdAt: .now),
    remoteProvider: any ReflectionProviding = ReflectionProviderFactory.makeRemoteProvider(),
    onCancel: @escaping () -> Void = {},
    onEntryCommitted: @escaping (CheckInEntry) -> Void = { _ in }
  ) {
    self.mode = mode
    self.remoteProvider = remoteProvider
    self.onCancel = onCancel
    self.onEntryCommitted = onEntryCommitted
  }

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
    .dailyBetterBackground()
    .task {
      guard viewModel == nil else { return }
      viewModel = CheckInViewModel(
        repository: SwiftDataCheckInRepository(context: modelContext),
        mode: mode,
        remoteProvider: remoteProvider,
        onEntryCommitted: { entry in
          dismissKeyboard()
          onEntryCommitted(entry)
        }
      )
    }
  }

  private func checkInContent(_ viewModel: CheckInViewModel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: contentSpacing) {
        VStack(alignment: .leading, spacing: 8) {
          Text(navigationTitle)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(DailyBetterStyle.tint)

          Text("How are you?")
            .font(.system(size: headingSize, weight: .bold, design: .rounded))
            .foregroundStyle(DailyBetterStyle.ink)
        }

        MoodSelector(selection: moodBinding(viewModel))
        noteEditor(viewModel)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .top, spacing: 0) {
      composerHeader(viewModel)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      actionDock(viewModel)
    }
    .confirmationDialog("Discard this entry?", isPresented: $confirmsDiscard) {
      Button("Discard entry", role: .destructive) {
        dismissComposer(viewModel)
      }
      Button("Keep writing", role: .cancel) {}
    } message: {
      Text("Your mood and writing have not been saved.")
    }
    .alert("Couldn't reflect right now", isPresented: failureBinding(viewModel)) {
      Button("Try again") {
        viewModel.startReflection()
      }
      Button("Save without reflection") {
        viewModel.saveWithoutReflection()
      }
      Button("Cancel", role: .cancel) {
        viewModel.failure = nil
      }
    } message: {
      Text("Your entry is still here.")
    }
    .alert("Couldn't save right now", isPresented: saveFailureBinding(viewModel)) {
      Button("Try saving again") {
        viewModel.retryFailedSave()
      }
      Button("Cancel", role: .cancel) {
        viewModel.saveFailure = false
      }
    } message: {
      Text(viewModel.saveFailureMessage)
    }
  }

  private var navigationTitle: String {
    switch mode {
    case .create:
      "NEW ENTRY"
    case .edit:
      "EDIT ENTRY"
    }
  }

  private func composerHeader(_ viewModel: CheckInViewModel) -> some View {
    HStack {
      Button(action: { requestCancel(viewModel) }) {
        Image(systemName: "xmark")
          .font(.system(size: 16, weight: .semibold))
          .frame(width: 44, height: 44)
      }
      .buttonStyle(.plain)
      .foregroundStyle(DailyBetterStyle.ink)
      .accessibilityLabel("Close")
      .accessibilityIdentifier("checkIn.close")

      Spacer()

      Text(mode.createdAt.formatted(date: .abbreviated, time: .shortened))
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(DailyBetterStyle.muted)
        .accessibilityIdentifier("checkIn.timestamp")

      Spacer()

      Color.clear.frame(width: 44, height: 44)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background(.ultraThinMaterial)
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
        .focused($isNoteFocused)
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

  private func actionDock(_ viewModel: CheckInViewModel) -> some View {
    let canSubmit = viewModel.selectedMood != nil && !viewModel.isReflecting

    return HStack(spacing: 12) {
      composerButton("Save", identifier: "checkIn.save", primary: false, isLoading: false) {
        viewModel.saveWithoutReflection()
      }
      .disabled(!canSubmit)

      composerButton("Reflect", identifier: "checkIn.reflect", primary: true, isLoading: viewModel.isReflecting) {
        viewModel.startReflection()
      }
      .disabled(!canSubmit)
    }
    .opacity(canSubmit ? 1 : 0.5)
    .padding(16)
    .background(.ultraThinMaterial)
  }

  private func composerButton(
    _ title: String,
    identifier: String,
    primary: Bool,
    isLoading: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView()
            .tint(.white)
        }
        Text(isLoading ? "Reflecting..." : title)
      }
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(primary ? .white : DailyBetterStyle.tint)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(primary ? DailyBetterStyle.darkAction : DailyBetterStyle.glass)
          .stroke(primary ? .clear : DailyBetterStyle.hairline, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
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

  private func saveFailureBinding(_ viewModel: CheckInViewModel) -> Binding<Bool> {
    Binding(
      get: { viewModel.saveFailure },
      set: { isPresented in
        if !isPresented {
          viewModel.saveFailure = false
        }
      }
    )
  }

  private func requestCancel(_ viewModel: CheckInViewModel) {
    if viewModel.hasUnsavedChanges {
      confirmsDiscard = true
    } else {
      dismissComposer(viewModel)
    }
  }

  private func dismissComposer(_ viewModel: CheckInViewModel) {
    viewModel.cancelReflection()
    dismissKeyboard()
    onCancel()
  }

  private func dismissKeyboard() {
    isNoteFocused = false
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}
