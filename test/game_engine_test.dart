import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/features/game/domain/game_config.dart';
import 'package:gear_spin/features/game/domain/game_engine.dart';
import 'package:gear_spin/features/game/domain/game_entities.dart';
import 'package:gear_spin/features/game/domain/level_config.dart';

void main() {
  test('a perfectly timed shot hits a ball (no tunnelling)', () {
    final engine = GameEngine(LevelConfig.forLevel(1));
    final events = <GameEvent>[];
    engine.onEvent = events.add;

    // Time of flight from spawn to the ring.
    const flight = (GameConfig.ringRadius - 20) / GameConfig.shotSpeed;
    var fired = false;

    for (var i = 0; i < 120 * 20 && !fired; i++) {
      // Predict where each ball will be when the shot reaches the ring.
      final futureRot = engine.rotation + engine.angularVelocity * flight;
      for (final t in engine.targets) {
        var d = (t.localAngle + futureRot - GameConfig.aimAngle) % (2 * math.pi);
        if (d > math.pi) d -= 2 * math.pi;
        if (t.type == TargetType.ball && d.abs() < 0.01) {
          fired = engine.shoot();
          break;
        }
      }
      engine.step(GameConfig.fixedStep);
    }
    expect(fired, isTrue);
    for (var i = 0; i < 120; i++) {
      engine.step(GameConfig.fixedStep);
    }
    expect(events, contains(GameEvent.hit));
    expect(engine.score, 100);
  });

  test('shots that hit nothing count as misses and can end the run', () {
    final engine = GameEngine(LevelConfig.forLevel(1));
    // Fire blindly until out of shots; with 3 balls on a wide ring at least
    // the engine must terminate in won or lost state.
    for (var i = 0; i < 120 * 60; i++) {
      engine.shoot();
      engine.step(GameConfig.fixedStep);
    }
    expect(engine.phase, anyOf(GamePhase.won, GamePhase.lost));
  });

  test('revive works once', () {
    final engine = GameEngine(LevelConfig.forLevel(1));
    for (var i = 0; i < 120 * 60 && engine.phase != GamePhase.lost; i++) {
      engine.shoot();
      engine.step(GameConfig.fixedStep);
    }
    if (engine.phase == GamePhase.lost) {
      expect(engine.revive(), isTrue);
      expect(engine.phase, GamePhase.playing);
      expect(engine.canRevive, isFalse);
    }
  });

  test('all 120 levels generate non-overlapping layouts', () {
    for (var n = 1; n <= LevelConfig.totalLevels; n++) {
      final layout = LevelConfig.forLevel(n).buildLayout();
      for (var i = 0; i < layout.length; i++) {
        final j = (i + 1) % layout.length;
        if (layout.length < 2) continue;
        var d = (layout[j].angle - layout[i].angle).abs() % (2 * math.pi);
        d = math.min(d, 2 * math.pi - d);
        expect(d * GameConfig.ringRadius, greaterThan(2 * GameConfig.targetRadius),
            reason: 'level $n targets overlap');
      }
    }
  });
}
