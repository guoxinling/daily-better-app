import SwiftUI

struct EntryDetailView: View {
  @Bindable var entry: CheckInEntry
  let onBack: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onSetHelpfulness: (Helpfulness) -> Void

  @State private var confirmsDeletion = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        entrySummaryCard

        if hasSavedReflectionContent {
          reflectionCard
        }

        if let suggestedAction = normalized(entry.suggestedActionText) {
          actionCard(suggestedAction)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 32)
    }
    .navigationTitle("Entry")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          onBack()
        } label: {
          Label("Timeline", systemImage: "chevron.left")
            .labelStyle(.titleAndIcon)
        }
        .accessibilityIdentifier("entry.back")
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit entry", action: onEdit)
          Button("Delete entry", role: .destructive) {
            confirmsDeletion = true
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("entry.menu")
      }
    }
    .toolbarBackground(DailyBetterStyle.top.opacity(0.94), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .dailyBetterBackground()
    .confirmationDialog("Delete this entry?", isPresented: $confirmsDeletion) {
      Button("Delete entry", role: .destructive, action: onDelete)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This journal entry and its reflection will be permanently removed.")
    }
  }

  private var entrySummaryCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(DailyBetterStyle.muted)

      Text("\(entry.mood.emoji) \(entry.mood.title)")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(DailyBetterStyle.tint)

      if let note = normalized(entry.noteText) {
        VStack(alignment: .leading, spacing: 10) {
          sectionLabel("Your note")

          Text(note)
            .font(.system(size: 18, design: .serif))
            .lineSpacing(5)
            .foregroundStyle(DailyBetterStyle.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("entry.note.full")
        }
      } else {
        Text("Only a feeling was recorded.")
          .font(.system(size: 18, design: .serif))
          .foregroundStyle(DailyBetterStyle.ink)
          .accessibilityIdentifier("entry.note.full")
      }

      if !entry.orderedAttachments.isEmpty {
        attachmentGrid
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DailyBetterStyle.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
  }

  private var attachmentGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 76, maximum: 76), spacing: 10)],
      alignment: .leading,
      spacing: 10
    ) {
      ForEach(entry.orderedAttachments) { attachment in
        StoredAttachmentImage(attachment: attachment)
          .frame(width: 76, height: 76)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .accessibilityIdentifier("entry.photo.thumbnail")
      }
    }
    .accessibilityIdentifier("entry.photo.grid")
  }

  private var reflectionCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("Reflection")

      if let reflectionText = normalized(entry.reflectionText) {
        Text(reflectionText)
          .font(.system(size: 20, design: .serif))
          .lineSpacing(5)
          .foregroundStyle(DailyBetterStyle.ink)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("reflection.title")
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DailyBetterStyle.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
  }

  private func actionCard(_ suggestedAction: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel("One small step")

      Text(suggestedAction)
        .font(.system(size: 17, weight: .semibold))
        .lineSpacing(3)
        .foregroundStyle(DailyBetterStyle.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("reflection.action")
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DailyBetterStyle.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)
    }
  }

  private func sectionLabel(_ title: String) -> some View {
    Text(title.uppercased())
      .font(.system(size: 12, weight: .bold, design: .rounded))
      .tracking(1.4)
      .foregroundStyle(DailyBetterStyle.tint)
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private var hasSavedReflectionContent: Bool {
    normalized(entry.reflectionText) != nil || normalized(entry.suggestedActionText) != nil
  }
}
