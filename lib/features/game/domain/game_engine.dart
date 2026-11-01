import 'dart:math' as math;

import 'game_config.dart';
import 'game_entities.dart';
import 'level_config.dart';

/// Pure-Dart game simulation (no Flutter imports) -> unit-testable.
///
/// Collision detection is *swept*: every step we test the segment the shot
/// travelled (prev -> current) against the target circle, at both the
/// target's previous and current rotation. A fast shot can therefore never
/// tunnel through a target, regardless of frame rate.
class GameEngine {
  GameEngine(this.level, {this.onEvent}) {
    reset();
  }

  final LevelConfig level;
  void Function(GameEvent event)? onEvent;

  late List<GearTarget> targets;
  final List<Shot> shots = [];
  final List<HitEffect> effects = [];

  GamePhase phase = GamePhase.ready;
  double rotation = 0;
  int score = 0;
  int combo = 0;
  int lives = 0;
  int shotsLeft = 0;
  int misses = 0;
  bool reviveUsed = false;

  double _time = 0;
  double _cooldown = 0;

  static final double _dirX = math.cos(GameConfig.aimAngle);
  static final double _dirY = math.sin(GameConfig.aimAngle);
  static double get shotDirX => _dirX;
  static double get shotDirY => _dirY;

  int get ballsLeft =>
      targets.where((t) => t.type == TargetType.ball && !t.hit).length;

  bool get canRevive => phase == GamePhase.lost && !reviveUsed;

  /// 1-3 stars. Perfect run (no miss, no life lost) = 3. Reviving caps at 1.
  int get stars {
    if (reviveUsed) return 1;
    final wasted = misses + (level.lives - lives);
    if (wasted == 0) return 3;
    return wasted <= 2 ? 2 : 1;
  }

  double get angularVelocity {
    final wobble = 1 + level.speedWobble * math.sin(_time * 1.7);
    return (level.clockwise ? 1 : -1) * level.baseSpeed * wobble;
  }

  void reset() {
    targets = [
      for (final s in level.buildLayout()) GearTarget(s.angle, s.type),
    ];
    shots.clear();
    effects.clear();
    phase = GamePhase.ready;
    rotation = 0;
    score = 0;
    combo = 0;
    misses = 0;
    lives = level.lives;
    shotsLeft = level.maxShots;
    reviveUsed = false;
    _time = 0;
    _cooldown = 0;
  }

  /// Returns true if a shot was actually fired.
  bool shoot() {
    if (phase == GamePhase.won || phase == GamePhase.lost) return false;
    if (_cooldown > 0 || shotsLeft <= 0) return false;
    phase = GamePhase.playing;
    shotsLeft--;
    _cooldown = GameConfig.shotCooldown;
    // Spawn just off-centre; the painter draws the gear on top so it appears
    // to emerge from the hub.
    shots.add(Shot(_dirX * 20, _dirY * 20));
    onEvent?.call(GameEvent.shoot);
    return true;
  }

  /// Rewarded-ad revive: one extra life + 3 extra shots, once per run.
  bool revive() {
    if (!canRevive) return false;
    reviveUsed = true;
    lives = 1;
    shotsLeft += 3;
    combo = 0;
    shots.clear();
    phase = GamePhase.playing;
    onEvent?.call(GameEvent.revived);
    return true;
  }

  /// Advance the simulation by [dt] seconds (call with a fixed step).
  void step(double dt) {
    _updateEffects(dt);
    if (phase == GamePhase.won || phase == GamePhase.lost) return;

    _time += dt;
    if (_cooldown > 0) _cooldown -= dt;

    final prevRotation = rotation;
    rotation += angularVelocity * dt;

    if (phase != GamePhase.playing) return;

    for (final shot in shots) {
      if (!shot.alive) continue;
      shot.prevX = shot.x;
      shot.prevY = shot.y;
      shot.x += _dirX * GameConfig.shotSpeed * dt;
      shot.y += _dirY * GameConfig.shotSpeed * dt;

      final target = _findHit(shot, prevRotation);
      if (target != null) {
        _resolveHit(shot, target);
      } else if (shot.x * shot.x + shot.y * shot.y >
          GameConfig.shotMaxDistance * GameConfig.shotMaxDistance) {
        shot.alive = false;
        misses++;
        combo = 0;
        onEvent?.call(GameEvent.miss);
      }
    }
    shots.removeWhere((s) => !s.alive);

    _checkEndConditions();
  }

  GearTarget? _findHit(Shot shot, double prevRotation) {
    GearTarget? best;
    var bestT = double.infinity;
    for (final target in targets) {
      if (target.hit) continue;
      final t = math.min(
        _sweep(shot, target, prevRotation) ?? double.infinity,
        _sweep(shot, target, rotation) ?? double.infinity,
      );
      if (t < bestT) {
        bestT = t;
        best = target;
      }
    }
    return best;
  }

  /// Returns the normalised position along the shot's path of the closest
  /// approach if it touches the target, otherwise null.
  double? _sweep(Shot shot, GearTarget target, double rot) {
    final a = target.localAngle + rot;
    final cx = math.cos(a) * GameConfig.ringRadius;
    final cy = math.sin(a) * GameConfig.ringRadius;

    final dx = shot.x - shot.prevX;
    final dy = shot.y - shot.prevY;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (((cx - shot.prevX) * dx + (cy - shot.prevY) * dy) / len2)
            .clamp(0.0, 1.0)
            .toDouble();

    final px = shot.prevX + dx * t - cx;
    final py = shot.prevY + dy * t - cy;
    const r = GameConfig.targetRadius + GameConfig.shotRadius;
    return px * px + py * py <= r * r ? t : null;
  }

  void _resolveHit(Shot shot, GearTarget target) {
    shot.alive = false;
    final a = target.localAngle + rotation;
    final tx = math.cos(a) * GameConfig.ringRadius;
    final ty = math.sin(a) * GameConfig.ringRadius;

    if (target.type == TargetType.ball) {
      target.hit = true;
      combo++;
      score += 100 * combo;
      effects.add(HitEffect(tx, ty, isHazard: false));
      onEvent?.call(GameEvent.hit);
    } else {
      lives--;
      combo = 0;
      effects.add(HitEffect(tx, ty, isHazard: true));
      onEvent?.call(GameEvent.hazard);
    }
  }

  void _checkEndConditions() {
    if (ballsLeft == 0) {
      phase = GamePhase.won;
      score += lives * 250 + shotsLeft * 50; // finishing bonus
      shots.clear();
      onEvent?.call(GameEvent.won);
    } else if (lives <= 0 || (shotsLeft == 0 && shots.isEmpty)) {
      phase = GamePhase.lost;
      shots.clear();
      onEvent?.call(GameEvent.lost);
    }
  }

  void _updateEffects(double dt) {
    for (final e in effects) {
      e.age += dt;
    }
    effects.removeWhere((e) => e.age >= HitEffect.lifetime);
  }
}
