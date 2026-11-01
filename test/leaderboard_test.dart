import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/features/auth/data/auth_repository.dart';
import 'package:gear_spin/features/auth/domain/auth_user.dart';
import 'package:gear_spin/features/auth/presentation/auth_provider.dart';
import 'package:gear_spin/features/leaderboard/data/leaderboard_repository.dart';
import 'package:gear_spin/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:gear_spin/features/leaderboard/presentation/leaderboard_provider.dart';
import 'package:gear_spin/features/levels/data/progress_repository.dart';
import 'package:gear_spin/features/levels/presentation/level_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = AuthUser(uid: 'me', isAnonymous: true);

void main() {
  group('PlayerProfile', () {
    test('username validation', () {
      expect(PlayerProfile.validateUsername('ab'), isNotNull);
      expect(PlayerProfile.validateUsername('a' * 17), isNotNull);
      expect(PlayerProfile.validateUsername('bad name'), isNotNull);
      expect(PlayerProfile.validateUsername('<script>'), isNotNull);
      expect(PlayerProfile.validateUsername('  Ali_99  '), isNull);
    });

    test('default name is stable per uid and valid', () {
      final a = PlayerProfile.defaultFor('uid-123');
      expect(a.username, PlayerProfile.defaultFor('uid-123').username);
      expect(PlayerProfile.validateUsername(a.username), isNull);
    });
  });

  group('LeaderboardProvider', () {
    late InMemoryLeaderboardRepository repo;
    late LeaderboardProvider board;

    setUp(() async {
      repo = InMemoryLeaderboardRepository();
      board = LeaderboardProvider(repo, deviceCountry: 'tr')..start();
      board.updateUser(_me);
      await pumpEventQueue();
    });

    tearDown(() => board.dispose());

    test('new player gets default profile with device country', () {
      expect(board.profile, isNotNull);
      expect(board.profile!.countryCode, 'TR');
      expect(board.entries, isEmpty);
      expect(board.standing, isNull);
    });

    test('submitted score appears live with rank 1', () async {
      await board.submitScore(500);
      await pumpEventQueue();
      expect(board.entries.single.uid, 'me');
      expect(board.entries.single.rank, 1);
      expect(board.standing!.highScore, 500);
      expect(board.isMeInTop, isTrue);
    });

    test('ranking is ordered and a lower score never replaces a higher one', () async {
      await repo.submitScore('other', 900, const PlayerProfile(username: 'Other', countryCode: 'US'));
      await board.submitScore(500);
      await board.submitScore(100);
      await pumpEventQueue();

      expect(board.entries.map((e) => e.uid), ['other', 'me']);
      expect(board.standing!.rank, 2);
      expect(board.standing!.highScore, 500);
    });

    test('rank is reported even when outside the visible top list', () async {
      final small = LeaderboardProvider(repo, limit: 2)..start();
      small.updateUser(_me);
      for (var i = 0; i < 3; i++) {
        await repo.submitScore('p$i', 1000 + i, PlayerProfile(username: 'Player$i', countryCode: ''));
      }
      await small.submitScore(10);
      await pumpEventQueue();

      expect(small.entries.length, 2);
      expect(small.isMeInTop, isFalse);
      expect(small.standing!.rank, 4);
      small.dispose();
    });

    test('profile update validates and is reflected on the board', () async {
      expect(await board.updateProfile(username: 'x', countryCode: 'US'), isNotNull);

      await board.submitScore(300);
      expect(await board.updateProfile(username: 'Nexalo_1', countryCode: 'jp'), isNull);
      await pumpEventQueue();

      expect(board.profile!.username, 'Nexalo_1');
      expect(board.profile!.countryCode, 'JP');
      expect(board.entries.single.username, 'Nexalo_1');
      expect(board.entries.single.countryCode, 'JP');
    });

    test('score is ignored when signed out or zero', () async {
      await board.submitScore(0);
      board.updateUser(null);
      await board.submitScore(999);
      await pumpEventQueue();
      expect(board.entries, isEmpty);
    });
  });

  group('AuthProvider', () {
    test('creates a guest automatically', () async {
      final auth = AuthProvider(LocalAuthRepository());
      await auth.init();
      expect(auth.isSignedIn, isTrue);
      expect(auth.isGuest, isTrue);
      expect(auth.error, isNull);
      auth.dispose();
    });

    test('google sign-in unavailable offline: error is reported, guest kept', () async {
      final auth = AuthProvider(LocalAuthRepository());
      await auth.init();
      await auth.signInWithGoogle();
      expect(auth.error, isNotNull);
      expect(auth.isSignedIn, isTrue);
      auth.dispose();
    });

    test('sign out falls back to a fresh guest', () async {
      final auth = AuthProvider(LocalAuthRepository());
      await auth.init();
      await auth.signOut();
      expect(auth.isSignedIn, isTrue);
      expect(auth.isGuest, isTrue);
      auth.dispose();
    });
  });

  test('leaderboard score = sum of best scores of all levels', () async {
    SharedPreferences.setMockInitialValues({});
    final levels = LevelProvider(LocalProgressRepository());
    await levels.load();
    await levels.completeLevel(level: 1, stars: 3, score: 400);
    await levels.completeLevel(level: 2, stars: 1, score: 250);
    await levels.completeLevel(level: 1, stars: 1, score: 100); // worse replay
    expect(levels.totalBestScore, 650);
  });
}
