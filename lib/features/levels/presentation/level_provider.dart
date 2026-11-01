import 'package:flutter/foundation.dart';

import '../../game/domain/level_config.dart';
import '../data/progress_repository.dart';
import '../domain/level_progress.dart';

/// Single source of truth for level unlock + star state.
///
/// Unlock rule: level 1 is always open; level N opens once level N-1 has been
/// completed (>= 1 star).
class LevelProvider extends ChangeNotifier {
  LevelProvider(this._repository);

  final ProgressRepository _repository;
  Map<int, LevelProgress> _progress = {};
  bool _isLoaded = false;

  static const int totalLevels = LevelConfig.totalLevels;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _progress = await _repository.load();
    _isLoaded = true;
    notifyListeners();
  }

  int starsOf(int level) => _progress[level]?.stars ?? 0;
  int bestScoreOf(int level) => _progress[level]?.bestScore ?? 0;
  bool isCompleted(int level) => starsOf(level) > 0;

  bool isUnlocked(int level) {
    if (level < 1 || level > totalLevels) return false;
    return level == 1 || isCompleted(level - 1);
  }

  /// The level the player should play next (first not-yet-completed one).
  int get currentLevel {
    for (var n = 1; n <= totalLevels; n++) {
      if (!isCompleted(n)) return n;
    }
    return totalLevels;
  }

  int get completedCount => _progress.values.where((p) => p.isCompleted).length;
  int get totalStars => _progress.values.fold(0, (sum, p) => sum + p.stars);
  int get maxStars => totalLevels * LevelProgress.maxStars;

  /// Sum of the best score of every level - this is the global leaderboard
  /// "High Score" (replaying a level can only raise it).
  int get totalBestScore => _progress.values.fold(0, (sum, p) => sum + p.bestScore);

  /// Records a finished level. Never lowers an existing star rating/score.
  Future<void> completeLevel({
    required int level,
    required int stars,
    required int score,
  }) async {
    if (level < 1 || level > totalLevels) return;
    final current = _progress[level] ?? const LevelProgress(stars: 0, bestScore: 0);
    _progress = {
      ..._progress,
      level: current.merge(stars: stars, score: score),
    };
    notifyListeners();
    await _repository.save(_progress);
  }
}
