/// What other players see about you.
class PlayerProfile {
  const PlayerProfile({required this.username, required this.countryCode});

  final String username;

  /// ISO alpha-2 (upper case) or '' when unknown.
  final String countryCode;

  static const int minNameLength = 3;
  static const int maxNameLength = 16;
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9_]+$');

  /// Returns an error message, or null when [name] is valid.
  static String? validateUsername(String name) {
    final n = name.trim();
    if (n.length < minNameLength || n.length > maxNameLength) {
      return 'Use $minNameLength-$maxNameLength characters';
    }
    if (!_allowed.hasMatch(n)) return 'Letters, numbers and _ only';
    return null;
  }

  /// Stable guest name derived from the uid (same uid -> same name).
  factory PlayerProfile.defaultFor(String uid, {String countryCode = ''}) {
    var h = 0;
    for (final unit in uid.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return PlayerProfile(
      username: 'Player${(h % 10000).toString().padLeft(4, '0')}',
      countryCode: countryCode,
    );
  }

  PlayerProfile copyWith({String? username, String? countryCode}) => PlayerProfile(
        username: username ?? this.username,
        countryCode: countryCode ?? this.countryCode,
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.rank,
    required this.username,
    required this.countryCode,
    required this.highScore,
  });

  final String uid;
  final int rank;
  final String username;
  final String countryCode;
  final int highScore;
}
