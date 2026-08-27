/// Outcome after auth init and the update gate have both settled.
enum LoginStartupOutcome {
  /// Auth is ready and navigation/bootstrap may proceed.
  readyToBootstrap,

  /// Auth is ready, but a mandatory update still blocks leaving login.
  blockedByUpdate,
}

/// Runs auth initialization without waiting on the update check first.
///
/// Update checking may start in parallel. Navigation is gated only after both
/// settle: a required/in-progress update blocks leaving login, but does not
/// undo auth readiness.
class LoginStartupCoordinator {
  const LoginStartupCoordinator();

  Future<LoginStartupOutcome> run({
    required Future<void> Function() initializeAuth,
    required Future<void> Function() checkUpdate,
    required bool Function() isUpdateBlocking,
  }) async {
    final updateFuture = checkUpdate();
    try {
      await initializeAuth();
    } finally {
      // Always settle the update future so a failed/slow check cannot leave
      // an unawaited error, and so the gate sees final update flags.
      await updateFuture;
    }

    if (isUpdateBlocking()) {
      return LoginStartupOutcome.blockedByUpdate;
    }
    return LoginStartupOutcome.readyToBootstrap;
  }
}
