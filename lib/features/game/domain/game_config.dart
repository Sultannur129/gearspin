import 'dart:math' as math;

/// All gameplay constants live in "world units". The world is a square whose
/// origin (0,0) is the gear centre; the painter scales it to the screen, so
/// physics is identical on every device.
abstract final class GameConfig {
  /// Half-width of the visible world.
  static const double worldHalfExtent = 200;

  static const double gearRadius = 76;

  /// Distance from the gear centre to the centre of each target.
  static const double ringRadius = 100;

  static const double targetRadius = 13;
  static const double shotRadius = 7;

  /// Units per second.
  static const double shotSpeed = 520;

  /// Shot is removed (= miss) once it travels past this distance.
  static const double shotMaxDistance = 190;

  /// Seconds between two shots.
  static const double shotCooldown = 0.14;

  /// Fixed physics step -> deterministic, frame-rate independent collisions.
  static const double fixedStep = 1 / 120;

  /// Shots travel straight up (screen -Y).
  static const double aimAngle = -math.pi / 2;
}
