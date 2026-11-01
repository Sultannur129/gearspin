enum TargetType { ball, hazard }

enum GamePhase { ready, playing, won, lost }

enum GameEvent { shoot, hit, hazard, miss, won, lost, revived }

/// A target attached to the gear. [localAngle] is relative to the gear, the
/// world angle is `localAngle + engine.rotation`.
class GearTarget {
  GearTarget(this.localAngle, this.type);

  final double localAngle;
  final TargetType type;
  bool hit = false;
}

class Shot {
  Shot(this.x, this.y)
      : prevX = x,
        prevY = y;

  double x, y;
  double prevX, prevY;
  bool alive = true;
}

/// Short-lived expanding ring drawn where something was hit.
class HitEffect {
  HitEffect(this.x, this.y, {required this.isHazard});

  final double x, y;
  final bool isHazard;
  double age = 0;

  static const double lifetime = 0.45;
  double get progress => (age / lifetime).clamp(0.0, 1.0);
}
