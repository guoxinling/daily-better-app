import Foundation

enum TimelineExportService {
  static func render(entries: [CheckInEntry], legacyAffirmations: [Affirmation]) -> String {
    var lines = ["Daily Better Timeline", ""]

    for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
      lines.append(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
      lines.append("Mood: \(entry.mood.emoji) \(entry.mood.title)")

      if let note = entry.noteText {
        lines.append(note)
      }

      if let reflection = entry.reflectionText {
        lines.append("Reflection: \(reflection)")
      }

      if let action = entry.suggestedActionText {
        lines.append("Small step: \(action)")
      }

      lines.append("")
    }

    let customAffirmations = legacyAffirmations.filter(\.isCustom)
    if !customAffirmations.isEmpty {
      lines.append("Legacy custom words")
      lines.append(contentsOf: customAffirmations.map { "- \($0.text)" })
    }

    return lines.joined(separator: "\n")
  }
}
