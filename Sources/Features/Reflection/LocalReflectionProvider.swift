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
    case .bright:
      (
        "Something feels good enough to notice. Let this moment be real without turning it into another task.",
        "Name one detail you want to remember from this moment."
      )
    case .calm:
      (
        "There is some steadiness here. You can let this moment be enough without asking it to become more.",
        "Notice one thing helping you feel grounded and stay with it for one breath."
      )
    case .okay:
      (
        "You may not need to label this moment as good or bad. Being here is enough information for now.",
        "Take one slow breath and name what you need next, if anything."
      )
    }
  }
}
