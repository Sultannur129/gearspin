import 'dart:math' as math;

import 'game_entities.dart';

class TargetSpec {
  const TargetSpec(this.angle, this.type);
  final double angle;
  final TargetType type;
}

/// Procedural difficulty curve -> 120 levels without hand-authoring each one.
/// Layouts are seeded by level number, so a level is identical on every run.
class LevelConfig {
  const LevelConfig._({
    required this.number,
    required this.ballCount,
    required this.hazardCount,
    required this.baseSpeed,
    required this.speedWobble,
    required this.clockwise,
    required this.maxShots,
    required this.lives,
  });

  static const int totalLevels = 120;

  final int number;
  final int ballCount;
  final int hazardCount;

  /// Radians per second.
  final double baseSpeed;

  /// 0..1 - how much the rotation speed oscillates (harder to time).
  final double speedWobble;
  final bool clockwise;
  final int maxShots;
  final int lives;

  factory LevelConfig.forLevel(int n) {
    final level = n.clamp(1, totalLevels);
    final balls = math.min(3 + (level - 1) ~/ 6, 12);
    final hazards = level < 4 ? 0 : math.min((level - 2) ~/ 8 + 1, 6);
    return LevelConfig._(
      number: level,
      ballCount: balls,
      hazardCount: hazards,
      baseSpeed: math.min(1.1 + level * 0.025, 3.4),
      speedWobble: level < 12 ? 0 : math.min((level - 11) * 0.012, 0.55),
      clockwise: level.isOdd,
      maxShots: balls + 4, // up to 4 misses allowed
      lives: 3,
    );
  }

  List<TargetSpec> buildLayout() {
    final rng = math.Random(number * 7919 + 13);
    final total = ballCount + hazardCount;
    final step = 2 * math.pi / total;
    final offset = rng.nextDouble() * 2 * math.pi;

    final types = <TargetType>[
      ...List.filled(ballCount, TargetType.ball),
      ...List.filled(hazardCount, TargetType.hazard),
    ]..shuffle(rng);

    return [
      for (var i = 0; i < total; i++)
        // Small jitter keeps neighbours from ever overlapping (<= 10% of step).
        TargetSpec(
          offset + i * step + (rng.nextDouble() - 0.5) * step * 0.2,
          types[i],
        ),
    ];
  }
}
