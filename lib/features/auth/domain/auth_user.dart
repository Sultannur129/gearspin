/// Identity only (who is playing). Profile data (username, country) lives with
/// the leaderboard feature.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.isAnonymous,
    this.displayName,
  });

  final String uid;

  /// True for guest accounts that have not linked Google yet.
  final bool isAnonymous;
  final String? displayName;
}

/// Thrown when the user dismisses the Google account picker (not an error).
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// Thrown when a sign-in method is not available (e.g. offline mode).
class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}
