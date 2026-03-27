import SwiftData
import SwiftUI

struct AddAffirmationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var text = ""
  @State private var selectedCategory: AffirmationCategory = .growth

  var body: some View {
    Form {
      Section("Your affirmation") {
        TextEditor(text: $text)
          .frame(minHeight: 160)
          .font(.system(size: 18, weight: .medium, design: .rounded))
      }

      Section("Category") {
        Picker("Category", selection: $selectedCategory) {
          ForEach(AffirmationCategory.allCases) { category in
            Text(category.title).tag(category)
          }
        }
        .pickerStyle(.inline)
      }
    }
    .navigationTitle("New Affirmation")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
          dismiss()
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button("Save") {
          save()
        }
        .fontWeight(.semibold)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private func save() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    modelContext.insert(
      Affirmation(
        text: trimmed,
        category: selectedCategory,
        isCustom: true,
        createdAt: .now
      )
    )
    try? modelContext.save()
    dismiss()
  }
}
