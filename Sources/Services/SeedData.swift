import Foundation

enum SeedData {
  struct AffirmationSeed {
    let text: String
    let category: AffirmationCategory
  }

  struct MoodSeed {
    let dayOffset: Int
    let mood: MoodKind
  }

  static let affirmations: [AffirmationSeed] = [
    .init(text: "I belong in the rooms I walk into.", category: .confidence),
    .init(text: "My voice deserves to be heard with calm confidence.", category: .confidence),
    .init(text: "I can be gentle and still take up space.", category: .confidence),
    .init(text: "I trust myself to learn what I do not know yet.", category: .confidence),
    .init(text: "I am allowed to begin before I feel fully ready.", category: .confidence),
    .init(text: "My progress matters more than perfection.", category: .confidence),
    .init(text: "I can hold self-respect in every conversation today.", category: .confidence),
    .init(text: "I carry enough strength for the next small step.", category: .confidence),
    .init(text: "I can give my attention to what matters most today.", category: .focus),
    .init(text: "One clear task is enough to make today meaningful.", category: .focus),
    .init(text: "I return to the present every time my mind wanders.", category: .focus),
    .init(text: "I create momentum by starting simply.", category: .focus),
    .init(text: "My attention is a gift, and I choose where it goes.", category: .focus),
    .init(text: "I can work with steadiness instead of urgency.", category: .focus),
    .init(text: "I do not need to rush to make real progress.", category: .focus),
    .init(text: "I can finish one thing well before chasing the next.", category: .focus),
    .init(text: "I am safe to slow down and breathe.", category: .calm),
    .init(text: "Peace can exist with unfinished things.", category: .calm),
    .init(text: "I soften my shoulders and return to myself.", category: .calm),
    .init(text: "I can let today be softer than yesterday.", category: .calm),
    .init(text: "Rest is part of becoming, not a detour from it.", category: .calm),
    .init(text: "I meet myself with patience instead of pressure.", category: .calm),
    .init(text: "I choose one peaceful breath over one more spiral.", category: .calm),
    .init(text: "I am allowed to reset at any point in the day.", category: .calm),
    .init(text: "I grow in honest, imperfect steps.", category: .growth),
    .init(text: "I can become better without becoming harder.", category: .growth),
    .init(text: "Every small effort is building a future self I trust.", category: .growth),
    .init(text: "I am not behind; I am still becoming.", category: .growth),
    .init(text: "I learn from today instead of judging it.", category: .growth),
    .init(text: "My life changes through steady days like this one.", category: .growth),
    .init(text: "I honor progress that looks quiet from the outside.", category: .growth),
    .init(text: "I am building a life that feels like mine.", category: .growth),
    .init(text: "I bring kindness into the way I speak and listen.", category: .relationships),
    .init(text: "I can protect my peace and still stay caring.", category: .relationships),
    .init(text: "Healthy relationships begin with honesty and softness.", category: .relationships),
    .init(text: "I am worthy of respect, tenderness, and clear love.", category: .relationships),
    .init(text: "I choose connection that feels safe and mutual.", category: .relationships),
    .init(text: "I can communicate my needs without apology.", category: .relationships),
    .init(text: "I notice the people who make me feel more like myself.", category: .relationships),
    .init(text: "I offer myself the compassion I hope to receive from others.", category: .relationships)
  ]

  static let screenshotMoods: [MoodSeed] = [
    .init(dayOffset: -6, mood: .steady),
    .init(dayOffset: -5, mood: .radiant),
    .init(dayOffset: -4, mood: .neutral),
    .init(dayOffset: -3, mood: .low),
    .init(dayOffset: -2, mood: .steady),
    .init(dayOffset: -1, mood: .tired),
    .init(dayOffset: 0, mood: .steady),
  ]

  static let screenshotCustomAffirmation = "I can build a better day with one honest choice at a time."
}
