/// Saved result of one level. Stars only ever go up: replaying a level and
/// doing worse never lowers the stored result.
class LevelProgress {
  const LevelProgress({required this.stars, required this.bestScore});

  /// 0 = not completed, 1-3 = completed with that rating.
  final int stars;
  final int bestScore;

  static const int maxStars = 3;

  bool get isCompleted => stars > 0;

  LevelProgress merge({required int stars, required int score}) => LevelProgress(
        stars: stars > this.stars ? stars.clamp(0, maxStars) : this.stars,
        bestScore: score > bestScore ? score : bestScore,
      );

  Map<String, dynamic> toJson() => {'s': stars, 'b': bestScore};

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        stars: ((json['s'] as num?)?.toInt() ?? 0).clamp(0, maxStars),
        bestScore: (json['b'] as num?)?.toInt() ?? 0,
      );
}
