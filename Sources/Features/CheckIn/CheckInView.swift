import SwiftData
import SwiftUI
import PhotosUI
import UIKit

private enum CheckInComposerAnchor {
  static let bottom = "checkInComposerBottom"
}

struct CheckInView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @ScaledMetric(relativeTo: .largeTitle) private var headingFontSize = 32.0
  @ScaledMetric(relativeTo: .body) private var noteFontSize = 17.0
  @FocusState private var isNoteFocused: Bool
  @State private var confirmsDiscard = false
  @State private var selectedPhotoItems: [PhotosPickerItem] = []
  @State private var speechController = SpeechToTextController()
  @State private var speechFailureMessage: String?
  @State private var attachmentFailureMessage: String?
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
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        speechController.cancel()
      }
    }
  }

  private func checkInContent(_ viewModel: CheckInViewModel) -> some View {
    ScrollViewReader { proxy in
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

          if let entry = viewModel.presentedEntry, viewModel.hasPreviewedReflection {
            ReflectionView(
              entry: entry,
              showsDoneButton: false,
              showsNavigationChrome: false,
              usesScrollView: false
            )
            .accessibilityIdentifier("checkIn.reflectionPreview")
          }

          Color.clear
            .frame(height: 1)
            .id(CheckInComposerAnchor.bottom)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, isNoteFocused ? 120 : 24)
      }
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: isNoteFocused) { _, focused in
        guard focused else { return }
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: 250_000_000)
          withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(CheckInComposerAnchor.bottom, anchor: .bottom)
          }
        }
      }
      .onChange(of: viewModel.noteText) { _, _ in
        guard isNoteFocused else { return }
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo(CheckInComposerAnchor.bottom, anchor: .bottom)
        }
      }
      .onChange(of: viewModel.presentedEntry?.id) { _, entryID in
        guard entryID != nil, viewModel.hasPreviewedReflection else { return }
        dismissKeyboard()
        withAnimation(.easeOut(duration: 0.25)) {
          proxy.scrollTo(CheckInComposerAnchor.bottom, anchor: .bottom)
        }
      }
      .onChange(of: selectedPhotoItems) { _, items in
        Task {
          await loadSelectedPhotos(items, into: viewModel)
        }
      }
    }
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
    .alert("Couldn't add photo", isPresented: attachmentFailureBinding) {
      Button("OK", role: .cancel) {
        attachmentFailureMessage = nil
      }
    } message: {
      Text(attachmentFailureMessage ?? "Please try another photo.")
    }
    .alert("Couldn't start voice input", isPresented: speechFailureBinding) {
      Button("OK", role: .cancel) {
        speechFailureMessage = nil
      }
    } message: {
      Text(speechFailureMessage ?? "Check microphone and speech recognition permissions.")
    }
    .onDisappear {
      speechController.cancel()
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
  }

  private func noteEditor(_ viewModel: CheckInViewModel) -> some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        ZStack(alignment: .topLeading) {
          if viewModel.noteText.isEmpty {
            Text("What's on your mind?")
              .font(.system(size: noteFontSize, design: .serif))
              .foregroundStyle(DailyBetterStyle.weakText)
              .padding(.horizontal, 5)
              .padding(.vertical, 8)
              .allowsHitTesting(false)
          }

          TextEditor(text: noteBinding(viewModel))
            .font(.system(size: noteFontSize, design: .serif))
            .lineSpacing(5)
            .foregroundStyle(DailyBetterStyle.ink)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, -4)
            .frame(minHeight: noteTextMinHeight, maxHeight: noteTextMaxHeight)
            .focused($isNoteFocused)
            .accessibilityLabel("What's on your mind?")
            .accessibilityIdentifier("checkIn.note")
        }

        if !viewModel.attachments.isEmpty {
          attachmentStrip(viewModel)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 14)

      Divider()
        .overlay(DailyBetterStyle.divider)
        .padding(.horizontal, 16)

      attachmentToolbar(viewModel)
    }
    .background(DailyBetterStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .onTapGesture {
      isNoteFocused = true
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
    dynamicTypeSize.isAccessibilitySize ? 180 : 220
  }

  private var noteTextMinHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 110 : 138
  }

  private var noteTextMaxHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 190 : (isNoteFocused ? 150 : 260)
  }

  private func attachmentStrip(_ viewModel: CheckInViewModel) -> some View {
    HStack(spacing: 8) {
      ForEach(Array(viewModel.attachments.prefix(3).enumerated()), id: \.element.id) { index, attachment in
        ZStack(alignment: .topTrailing) {
          attachmentThumbnail(attachment, overflowCount: overflowCount(index: index, total: viewModel.attachments.count))

          Button {
            viewModel.removeAttachment(id: attachment.id)
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(DailyBetterStyle.ink)
              .frame(width: 22, height: 22)
              .background(.white, in: Circle())
              .shadow(color: Color.black.opacity(0.12), radius: 4, y: 1)
          }
          .buttonStyle(.plain)
          .offset(x: 6, y: -6)
          .accessibilityLabel("Remove photo")
          .accessibilityIdentifier("checkIn.photo.remove")
        }
      }
    }
    .accessibilityIdentifier("checkIn.photo.strip")
  }

  private func attachmentThumbnail(_ attachment: DraftAttachment, overflowCount: Int?) -> some View {
    ZStack {
      if let image = UIImage(data: attachment.previewData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        DailyBetterStyle.selectedMoodBackground
      }

      if let overflowCount {
        Color.black.opacity(0.38)
        Text("+\(overflowCount)")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
      }
    }
    .frame(width: 64, height: 64)
    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
  }

  private func overflowCount(index: Int, total: Int) -> Int? {
    guard index == 2, total > 3 else { return nil }
    return total - 3
  }

  private func attachmentToolbar(_ viewModel: CheckInViewModel) -> some View {
    HStack(spacing: 18) {
      PhotosPicker(
        selection: $selectedPhotoItems,
        maxSelectionCount: max(0, CheckInViewModel.maxAttachmentCount - viewModel.attachments.count),
        matching: .images
      ) {
        Label("Add photo", systemImage: "photo")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(DailyBetterStyle.tint)
          .frame(minHeight: 44)
      }
      .disabled(viewModel.attachments.count >= CheckInViewModel.maxAttachmentCount)
      .accessibilityIdentifier("checkIn.addPhoto")

      Button {
        Task {
          await toggleSpeech(in: viewModel)
        }
      } label: {
        Image(systemName: speechController.isListening ? "stop.circle.fill" : "mic")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(speechController.isListening ? DailyBetterStyle.tint : DailyBetterStyle.tint.opacity(0.55))
          .frame(width: 44, height: 44)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(speechController.isListening ? "Stop voice input" : "Start voice input")
      .accessibilityIdentifier("checkIn.voiceInput")

      Spacer()

      Text("\(viewModel.noteText.count) / \(CheckInViewModel.noteCharacterLimit)")
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(characterCountColor(viewModel.noteText.count))
        .monospacedDigit()
        .accessibilityIdentifier("checkIn.characterCount")
    }
    .padding(.horizontal, 16)
    .frame(height: 48)
  }

  private func actionDock(_ viewModel: CheckInViewModel) -> some View {
    let canSubmit = viewModel.selectedMood != nil && !viewModel.isReflecting

    return HStack(spacing: 12) {
      HStack(spacing: 12) {
        if viewModel.hasPreviewedReflection {
          composerButton("Edit note", identifier: "checkIn.editNote", primary: false, isLoading: false) {
            isNoteFocused = true
          }
          .disabled(!canSubmit)

          composerButton(
            "Save to Timeline",
            identifier: "checkIn.savePreviewedReflection",
            primary: true,
            isLoading: false
          ) {
            speechController.cancel()
            dismissKeyboard()
            viewModel.savePreviewedReflection()
          }
          .disabled(!canSubmit)
        } else {
          composerButton("Save", identifier: "checkIn.save", primary: false, isLoading: false) {
            speechController.cancel()
            dismissKeyboard()
            viewModel.saveWithoutReflection()
          }
          .disabled(!canSubmit)

          composerButton("Reflect", identifier: "checkIn.reflect", primary: true, isLoading: viewModel.isReflecting) {
            speechController.cancel()
            dismissKeyboard()
            viewModel.startReflection()
          }
          .disabled(!canSubmit)
        }
      }
      .frame(maxWidth: .infinity)
      .opacity(canSubmit ? 1 : 0.5)

      if isNoteFocused {
        hideKeyboardButton
          .frame(width: 52, height: 52)
          .fixedSize()
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 10)
    .padding(.bottom, 12)
    .frame(minHeight: 70)
    .background(DailyBetterStyle.keyboardBar)
    .overlay(alignment: .top) {
      DailyBetterStyle.divider.frame(height: 1)
    }
  }

  private var hideKeyboardButton: some View {
    Image(systemName: "keyboard.chevron.compact.down")
      .font(.system(size: 17, weight: .semibold))
      .foregroundStyle(DailyBetterStyle.tint)
      .frame(width: 52, height: 52)
      .background(DailyBetterStyle.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(DailyBetterStyle.hairline, lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .onTapGesture {
        dismissKeyboard()
      }
      .accessibilityElement()
      .accessibilityLabel("Hide keyboard")
      .accessibilityAddTraits(.isButton)
      .accessibilityIdentifier("checkIn.hideKeyboard")
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
      .font(.system(size: 17, weight: .semibold))
      .foregroundStyle(primary ? .white : DailyBetterStyle.tint)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(primary ? DailyBetterStyle.tint : DailyBetterStyle.card)
          .stroke(primary ? .clear : DailyBetterStyle.hairline, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }

  private func moodBinding(_ viewModel: CheckInViewModel) -> Binding<CheckInMood?> {
    Binding(
      get: { viewModel.selectedMood },
      set: { viewModel.updateMood($0) }
    )
  }

  private func noteBinding(_ viewModel: CheckInViewModel) -> Binding<String> {
    Binding(
      get: { viewModel.noteText },
      set: { viewModel.updateNoteText($0) }
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
    speechController.cancel()
    dismissKeyboard()
    onCancel()
  }

  private func dismissKeyboard() {
    isNoteFocused = false
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }

  private var attachmentFailureBinding: Binding<Bool> {
    Binding(
      get: { attachmentFailureMessage != nil },
      set: { isPresented in
        if !isPresented {
          attachmentFailureMessage = nil
        }
      }
    )
  }

  private var speechFailureBinding: Binding<Bool> {
    Binding(
      get: { speechFailureMessage != nil },
      set: { isPresented in
        if !isPresented {
          speechFailureMessage = nil
        }
      }
    )
  }

  private func loadSelectedPhotos(_ items: [PhotosPickerItem], into viewModel: CheckInViewModel) async {
    defer { selectedPhotoItems = [] }
    guard !items.isEmpty else { return }

    for item in items {
      do {
        guard let data = try await item.loadTransferable(type: Data.self) else { continue }
        try viewModel.addAttachmentData(data)
      } catch {
        attachmentFailureMessage = "The selected photo could not be added."
        return
      }
    }
  }

  private func toggleSpeech(in viewModel: CheckInViewModel) async {
    do {
      try await speechController.toggle(existingText: viewModel.noteText) { text in
        viewModel.updateNoteText(text)
      } onFailure: { error in
        speechFailureMessage = speechFailureText(for: error)
      }
      if speechController.isListening {
        isNoteFocused = true
      }
    } catch {
      speechController.cancel()
      speechFailureMessage = speechFailureText(for: error)
    }
  }

  private func speechFailureText(for error: Error) -> String {
    SpeechToTextFailureMessage.text(for: error)
  }

  private func characterCountColor(_ count: Int) -> Color {
    if count >= CheckInViewModel.noteCharacterLimit {
      return Color(red: 166 / 255, green: 112 / 255, blue: 44 / 255)
    }
    if count >= 450 {
      return DailyBetterStyle.tint
    }
    return DailyBetterStyle.muted
  }
}
