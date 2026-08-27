/// Categories for auth/profile failures in the login stack.
enum AuthErrorKind {
  signIn,
  signOut,
  currentUser,
  profileEnsure,
}

/// Typed failure from auth/profile repositories. Presentation reports Crashlytics.
class AuthFailure implements Exception {
  const AuthFailure({
    required this.kind,
    required this.message,
    this.cause,
    this.code,
  });

  final AuthErrorKind kind;
  final String message;
  final Object? cause;
  final String? code;

  @override
  String toString() => message;
}
