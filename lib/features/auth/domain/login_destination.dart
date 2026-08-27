/// Where to send the user after auth is known.
///
/// Matches LoginScreen routing: shared-only users go to main, not chatbot.
enum LoginDestination {
  chatbot,
  mainPersonal,
  mainShared,
}

/// Decide post-login destination from personal and shared budget presence.
LoginDestination decideLoginDestination({
  required bool hasPersonalBudgets,
  required bool hasSharedBudgets,
}) {
  if (!hasPersonalBudgets && !hasSharedBudgets) {
    return LoginDestination.chatbot;
  }
  if (!hasPersonalBudgets) {
    return LoginDestination.mainShared;
  }
  return LoginDestination.mainPersonal;
}
