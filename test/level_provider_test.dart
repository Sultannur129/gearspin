import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/features/levels/data/progress_repository.dart';
import 'package:gear_spin/features/levels/domain/level_progress.dart';
import 'package:gear_spin/features/levels/presentation/level_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryRepository implements ProgressRepository {
  Map<int, LevelProgress> stored = {};

  @override
  Future<Map<int, LevelProgress>> load() async => stored;

  @override
  Future<void> save(Map<int, LevelProgress> progress) async => stored = progress;
}

void main() {
  late _MemoryRepository repo;
  late LevelProvider levels;

  setUp(() async {
    repo = _MemoryRepository();
    levels = LevelProvider(repo);
    await levels.load();
  });

  test('only level 1 is unlocked on a fresh install', () {
    expect(levels.isUnlocked(1), isTrue);
    expect(levels.isUnlocked(2), isFalse);
    expect(levels.currentLevel, 1);
    expect(levels.totalStars, 0);
  });

  test('completing a level unlocks the next one only', () async {
    await levels.completeLevel(level: 1, stars: 2, score: 500);
    expect(levels.isUnlocked(2), isTrue);
    expect(levels.isUnlocked(3), isFalse);
    expect(levels.currentLevel, 2);
  });

  test('stars and score never decrease on replay', () async {
    await levels.completeLevel(level: 1, stars: 3, score: 900);
    await levels.completeLevel(level: 1, stars: 1, score: 200);
    expect(levels.starsOf(1), 3);
    expect(levels.bestScoreOf(1), 900);
    await levels.completeLevel(level: 1, stars: 3, score: 1200);
    expect(levels.bestScoreOf(1), 1200);
  });

  test('out-of-range levels are ignored / locked', () async {
    await levels.completeLevel(level: 0, stars: 3, score: 1);
    await levels.completeLevel(level: LevelProvider.totalLevels + 1, stars: 3, score: 1);
    expect(levels.completedCount, 0);
    expect(levels.isUnlocked(LevelProvider.totalLevels + 1), isFalse);
  });

  test('finishing every level keeps currentLevel at the last one', () async {
    for (var n = 1; n <= LevelProvider.totalLevels; n++) {
      await levels.completeLevel(level: n, stars: 3, score: 1);
    }
    expect(levels.currentLevel, LevelProvider.totalLevels);
    expect(levels.totalStars, levels.maxStars);
  });

  test('local repository round-trips and survives corrupt data', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalProgressRepository();
    await local.save({
      4: const LevelProgress(stars: 2, bestScore: 777),
    });
    final loaded = await local.load();
    expect(loaded[4]!.stars, 2);
    expect(loaded[4]!.bestScore, 777);

    SharedPreferences.setMockInitialValues({'level_progress_v1': '{not json'});
    expect(await LocalProgressRepository().load(), isEmpty);
  });
}
