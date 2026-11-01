import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/countries.dart';
import '../../auth/domain/auth_user.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_entry.dart';

/// Live global ranking + the signed-in player's profile and standing.
class LeaderboardProvider extends ChangeNotifier {
  LeaderboardProvider(
    this._repository, {
    this.limit = 100,
    String deviceCountry = '',
  }) : _deviceCountry = deviceCountry.toUpperCase();

  final LeaderboardRepository _repository;
  final int limit;
  final String _deviceCountry;

  StreamSubscription<List<LeaderboardEntry>>? _sub;
  AuthUser? _user;
  PlayerProfile? _profile;
  List<LeaderboardEntry> _entries = const [];
  LeaderboardEntry? _standing;
  bool _loading = true;
  String? _error;

  List<LeaderboardEntry> get entries => _entries;
  LeaderboardEntry? get standing => _standing;
  PlayerProfile? get profile => _profile;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get myUid => _user?.uid;
  bool get isMeInTop => _entries.any((e) => e.uid == myUid);

  /// Subscribe to the live top list.
  void start() => _listen();

  void retry() => _listen();

  void _listen() {
    _sub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();
    _sub = _repository.watchTop(limit).listen(
      (list) {
        _entries = list;
        _loading = false;
        _error = null;
        notifyListeners();
        _refreshStanding();
      },
      onError: (Object e) {
        debugPrint('Leaderboard stream error: $e');
        _loading = false;
        _error = 'Could not load the leaderboard.';
        notifyListeners();
      },
    );
  }

  /// Called by ChangeNotifierProxyProvider whenever auth changes. Runs during
  /// the build phase, so it must not notify synchronously.
  void updateUser(AuthUser? user) {
    final changed = user?.uid != _user?.uid;
    _user = user;
    if (!changed) return;
    _profile = null;
    _standing = null;
    if (user != null) scheduleMicrotask(() => _loadProfile(user.uid));
  }

  PlayerProfile _defaultProfile(String uid) => PlayerProfile.defaultFor(
        uid,
        countryCode: isKnownCountry(_deviceCountry) ? _deviceCountry : '',
      );

  Future<void> _loadProfile(String uid) async {
    PlayerProfile? loaded;
    try {
      loaded = await _repository.loadProfile(uid);
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
    if (_user?.uid != uid) return; // user switched meanwhile
    _profile = loaded ?? _defaultProfile(uid);
    notifyListeners();
    await _refreshStanding();
  }

  Future<void> _refreshStanding() async {
    final uid = _user?.uid;
    if (uid == null) return;
    try {
      final s = await _repository.fetchStanding(uid);
      if (_user?.uid != uid) return;
      _standing = s;
      notifyListeners();
    } catch (e) {
      debugPrint('Standing refresh failed: $e');
    }
  }

  /// Submit the player's total score. Safe to call after every level - the
  /// backend only keeps a score that beats the saved one.
  Future<void> submitScore(int score) async {
    final user = _user;
    if (user == null || score <= 0) return;
    // Never overwrite a stored username with a default one.
    if (_profile == null) await _loadProfile(user.uid);
    final profile = _profile ?? _defaultProfile(user.uid);
    try {
      await _repository.submitScore(user.uid, score, profile);
      await _refreshStanding();
    } catch (e) {
      debugPrint('Score submit failed: $e');
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> updateProfile({
    required String username,
    required String countryCode,
  }) async {
    final user = _user;
    if (user == null) return 'Not signed in';
    final invalid = PlayerProfile.validateUsername(username);
    if (invalid != null) return invalid;

    final next = PlayerProfile(
      username: username.trim(),
      countryCode: countryCode.toUpperCase(),
    );
    try {
      await _repository.saveProfile(user.uid, next);
      _profile = next;
      notifyListeners();
      await _refreshStanding();
      return null;
    } catch (e) {
      debugPrint('Profile save failed: $e');
      return 'Could not save. Check your connection.';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
