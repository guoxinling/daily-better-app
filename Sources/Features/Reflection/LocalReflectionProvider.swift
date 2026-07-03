struct LocalReflectionProvider: ReflectionProviding {
  func reflect(_ request: ReflectionRequest) async throws -> ReflectionResult {
    let copy = copy(for: request.mood)
    return ReflectionResult(
      reflectionText: copy.reflection,
      suggestedActionText: copy.action,
      source: .local
    )
  }

  private func copy(for mood: CheckInMood) -> (reflection: String, action: String) {
    switch mood {
    case .anxious:
      (
        "Your mind is looking ahead for what might go wrong. You only need to meet the next moment.",
        "Name one thing you can control in the next five minutes."
      )
    case .overwhelmed:
      (
        "Several things may be asking for your attention at once. You do not need to solve the whole day now.",
        "Choose the task with the nearest real consequence and give it five minutes."
      )
    case .low:
      (
        "This moment feels heavy. You are allowed to lower the demands you place on yourself.",
        "Do one caring thing for your body: water, food, fresh air, or rest."
      )
    case .frustrated:
      (
        "Something is pushing against what you expected or needed. A pause can keep frustration from choosing the next move.",
        "Relax your jaw and shoulders, then write the outcome you actually need."
      )
    case .drained:
      (
        "Your energy is limited right now. A smaller version of the day still counts.",
        "Reduce the next task until it can be started in two minutes."
      )
    case .good:
      (
        "Something feels good enough to notice. Let this moment be real without turning it into another task.",
        "Name one detail you want to remember from this moment."
      )
    }
  }
}
