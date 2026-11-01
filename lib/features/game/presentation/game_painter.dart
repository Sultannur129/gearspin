import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/game_config.dart';
import '../domain/game_engine.dart';
import '../domain/game_entities.dart';
import 'game_controller.dart';

/// Renders the world. Repaints on every controller notification (every frame)
/// without rebuilding any widget.
class GamePainter extends CustomPainter {
  GamePainter(this.controller) : super(repaint: controller);

  final GameController controller;

  // Cached geometry/paints - nothing heavy is allocated per frame.
  static final Path _gear = _buildGearPath();
  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

  static const _ballColor = Color(0xFF3CC8FF);
  static const _hazardColor = Color(0xFFE5243B);

  @override
  void paint(Canvas canvas, Size size) {
    final engine = controller.engine;
    final rect = Offset.zero & size;

    _fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF9A3D), Color(0xFFEF4A2E)],
      ).createShader(rect)
      ..color = Colors.white;
    canvas.drawRect(rect, _fill);
    _fill.shader = null;

    final scale = size.width / (GameConfig.worldHalfExtent * 2);
    canvas
      ..save()
      ..translate(size.width / 2, size.height * 0.44)
      ..scale(scale);

    _drawRing(canvas);
    _drawShots(canvas, engine);
    _drawGear(canvas, engine);
    _drawTargets(canvas, engine);
    _drawEffects(canvas, engine);
    _drawAimMarker(canvas);

    canvas.restore();
  }

  void _drawRing(Canvas canvas) {
    _stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset.zero, GameConfig.ringRadius, _stroke);
  }

  void _drawShots(Canvas canvas, GameEngine engine) {
    final dx = GameEngine.shotDirX, dy = GameEngine.shotDirY;
    final skin = controller.skin;
    for (final s in engine.shots) {
      _stroke
        ..strokeWidth = GameConfig.shotRadius * 1.4
        ..strokeCap = StrokeCap.round
        ..color = skin.trail.withValues(alpha: 0.55);
      canvas.drawLine(
        Offset(s.x - dx * skin.trailLength, s.y - dy * skin.trailLength),
        Offset(s.x, s.y),
        _stroke,
      );
      _stroke.strokeCap = StrokeCap.butt;

      _glow.color = skin.glow.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(s.x, s.y), GameConfig.shotRadius * 1.6, _glow);
      _fill.color = skin.core;
      canvas.drawCircle(Offset(s.x, s.y), GameConfig.shotRadius, _fill);
    }
  }

  void _drawGear(Canvas canvas, GameEngine engine) {
    canvas
      ..save()
      ..rotate(engine.rotation);
    _fill.color = const Color(0xFF2C3B70);
    canvas.drawPath(_gear, _fill);
    _stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5B70B8);
    canvas.drawPath(_gear, _stroke);
    _fill.color = const Color(0xFF1B2650);
    canvas.drawCircle(Offset.zero, 9, _fill);
    canvas.restore();
  }

  void _drawTargets(Canvas canvas, GameEngine engine) {
    const ring = GameConfig.ringRadius;
    const r = GameConfig.targetRadius;

    for (final t in engine.targets) {
      if (t.hit) continue;
      canvas
        ..save()
        ..rotate(t.localAngle + engine.rotation);

      // Stem connecting target to the gear rim.
      _stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF3B4A85);
      canvas.drawLine(const Offset(GameConfig.gearRadius - 14, 0), const Offset(ring, 0), _stroke);

      canvas.translate(ring, 0);
      if (t.type == TargetType.ball) {
        _glow.color = _ballColor.withValues(alpha: 0.9);
        canvas.drawCircle(Offset.zero, r * 1.25, _glow);
        _fill.color = _ballColor;
        canvas.drawCircle(Offset.zero, r, _fill);
        _fill.color = Colors.white.withValues(alpha: 0.85);
        canvas.drawCircle(const Offset(-3, -3), r * 0.38, _fill);
      } else {
        // Spike pointing away from the gear.
        final spike = Path()
          ..moveTo(r + 8, 0)
          ..lineTo(-r * 0.7, -r)
          ..lineTo(-r * 0.7, r)
          ..close();
        _fill.color = _hazardColor;
        canvas.drawPath(spike, _fill);
        _stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.6);
        canvas.drawPath(spike, _stroke);
      }
      canvas.restore();
    }
  }

  void _drawEffects(Canvas canvas, GameEngine engine) {
    for (final e in engine.effects) {
      final p = e.progress;
      _stroke
        ..strokeWidth = 4 * (1 - p) + 1
        ..color = (e.isHazard ? _hazardColor : Colors.white).withValues(alpha: 1 - p);
      canvas.drawCircle(Offset(e.x, e.y), GameConfig.targetRadius + 34 * p, _stroke);
    }
  }

  void _drawAimMarker(Canvas canvas) {
    final y = -(GameConfig.ringRadius + 34);
    final marker = Path()
      ..moveTo(-8, y - 6)
      ..lineTo(8, y - 6)
      ..lineTo(0, y + 6)
      ..close();
    _fill.color = Colors.white.withValues(alpha: 0.55);
    canvas.drawPath(marker, _fill);
  }

  static Path _buildGearPath() {
    const teeth = 12;
    const outer = GameConfig.gearRadius;
    const inner = outer - 10;
    const step = 2 * math.pi / teeth;

    final body = Path();
    for (var i = 0; i < teeth; i++) {
      final a = i * step;
      final pts = <List<double>>[
        [a, inner],
        [a + step * 0.14, outer],
        [a + step * 0.36, outer],
        [a + step * 0.50, inner],
      ];
      for (var j = 0; j < pts.length; j++) {
        final o = Offset(math.cos(pts[j][0]) * pts[j][1], math.sin(pts[j][0]) * pts[j][1]);
        (i == 0 && j == 0) ? body.moveTo(o.dx, o.dy) : body.lineTo(o.dx, o.dy);
      }
    }
    body.close();

    // Hollow out the centre, then add 3 spokes + hub.
    var gear = Path.combine(
      PathOperation.difference,
      body,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: inner * 0.74)),
    );
    for (var k = 0; k < 3; k++) {
      final spoke = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(0, -7, inner * 0.8, 7),
          const Radius.circular(6),
        ));
      gear = Path.combine(
        PathOperation.union,
        gear,
        spoke.transform(Matrix4.rotationZ(k * 2 * math.pi / 3 + math.pi / 2).storage),
      );
    }
    return Path.combine(
      PathOperation.union,
      gear,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 17)),
    );
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => oldDelegate.controller != controller;
}
