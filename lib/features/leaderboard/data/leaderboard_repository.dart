import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/leaderboard_entry.dart';

/// Backend boundary for the global ranking.
///
/// "High score" = the player's total of best scores over all levels
/// (see LevelProvider.totalBestScore).
abstract class LeaderboardRepository {
  /// Live top list, best first (rank 1..n).
  Stream<List<LeaderboardEntry>> watchTop(int limit);

  /// The player's own entry with their global rank, or null if never scored.
  Future<LeaderboardEntry?> fetchStanding(String uid);

  /// Stores [score] only if it beats the saved one; always refreshes profile.
  Future<void> submitScore(String uid, int score, PlayerProfile profile);

  Future<PlayerProfile?> loadProfile(String uid);
  Future<void> saveProfile(String uid, PlayerProfile profile);
}

/// users/{uid} -> { username, countryCode, highScore, updatedAt }
class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  LeaderboardEntry _toEntry(String uid, Map<String, dynamic> data, int rank) =>
      LeaderboardEntry(
        uid: uid,
        rank: rank,
        username: (data['username'] as String?) ?? 'Player',
        countryCode: (data['countryCode'] as String?) ?? '',
        highScore: (data['highScore'] as num?)?.toInt() ?? 0,
      );

  @override
  Stream<List<LeaderboardEntry>> watchTop(int limit) {
    return _users
        .where('highScore', isGreaterThan: 0)
        .orderBy('highScore', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => [
              for (var i = 0; i < snap.docs.length; i++)
                _toEntry(snap.docs[i].id, snap.docs[i].data(), i + 1),
            ]);
  }

  @override
  Future<LeaderboardEntry?> fetchStanding(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final score = (data['highScore'] as num?)?.toInt() ?? 0;
    if (score <= 0) return null;

    // Server-side count: no need to download every better player.
    final better = await _users.where('highScore', isGreaterThan: score).count().get();
    return _toEntry(uid, data, (better.count ?? 0) + 1);
  }

  @override
  Future<void> submitScore(String uid, int score, PlayerProfile profile) {
    final ref = _users.doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final saved = (snap.data()?['highScore'] as num?)?.toInt() ?? 0;
      tx.set(
        ref,
        <String, Object?>{
          'username': profile.username,
          'countryCode': profile.countryCode,
          'highScore': math.max(saved, score),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<PlayerProfile?> loadProfile(String uid) async {
    final data = (await _users.doc(uid).get()).data();
    if (data == null) return null;
    return PlayerProfile(
      username: (data['username'] as String?) ?? PlayerProfile.defaultFor(uid).username,
      countryCode: (data['countryCode'] as String?) ?? '',
    );
  }

  @override
  Future<void> saveProfile(String uid, PlayerProfile profile) {
    return _users.doc(uid).set(
      <String, Object?>{
        'username': profile.username,
        'countryCode': profile.countryCode,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

/// Offline / test implementation. Holds only the players that were written to
/// it (i.e. just this device's player when Firebase is disabled).
class InMemoryLeaderboardRepository implements LeaderboardRepository {
  final Map<String, ({PlayerProfile profile, int score})> _players = {};
  final _changes = StreamController<void>.broadcast();

  List<LeaderboardEntry> _ranked() {
    final sorted = _players.entries.where((e) => e.value.score > 0).toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    return [
      for (var i = 0; i < sorted.length; i++)
        LeaderboardEntry(
          uid: sorted[i].key,
          rank: i + 1,
          username: sorted[i].value.profile.username,
          countryCode: sorted[i].value.profile.countryCode,
          highScore: sorted[i].value.score,
        ),
    ];
  }

  @override
  Stream<List<LeaderboardEntry>> watchTop(int limit) async* {
    yield _ranked().take(limit).toList();
    yield* _changes.stream.map((_) => _ranked().take(limit).toList());
  }

  @override
  Future<LeaderboardEntry?> fetchStanding(String uid) async {
    for (final e in _ranked()) {
      if (e.uid == uid) return e;
    }
    return null;
  }

  @override
  Future<void> submitScore(String uid, int score, PlayerProfile profile) async {
    final saved = _players[uid]?.score ?? 0;
    _players[uid] = (profile: profile, score: math.max(saved, score));
    _changes.add(null);
  }

  @override
  Future<PlayerProfile?> loadProfile(String uid) async => _players[uid]?.profile;

  @override
  Future<void> saveProfile(String uid, PlayerProfile profile) async {
    _players[uid] = (profile: profile, score: _players[uid]?.score ?? 0);
    _changes.add(null);
  }
}
