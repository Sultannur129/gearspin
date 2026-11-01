// Gear Spin brand asset generator.
//
// Renders the app logo with the exact same palette/gear geometry used in the
// game (see game_painter.dart) and writes every icon size needed for
// Android (legacy, adaptive, monochrome), iOS, web and Google Play Store.
//
// Run from the project root:
//   flutter test tool/generate_icons_test.dart
//
// (Implemented as a test only because it needs dart:ui's rasteriser.)
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _bgTop = Color(0xFFFF9A3D);
const _bgBottom = Color(0xFFEF4A2E);
const _gearTop = Color(0xFF3A4C94);
const _gearBottom = Color(0xFF1B2650);
const _gearEdge = Color(0xFF6A80CC);
const _stem = Color(0xFF2C3B70);
const _ball = Color(0xFF3CC8FF);
const _hazard = Color(0xFFE5243B);

// The artwork lives in a 1024x1024 design space. Everything is kept inside a
// radius of ~335 so it survives the Android adaptive-icon safe zone (66 %).
const double _gearR = 215;
const double _ringR = 285;
const double _ballR = 46;

Path _gearPath() {
  const teeth = 12;
  const outer = _gearR;
  const inner = outer - 32;
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

  var gear = Path.combine(
    PathOperation.difference,
    body,
    Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: inner * 0.74)),
  );
  for (var k = 0; k < 3; k++) {
    final spoke = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(0, -22, inner * 0.8, 22),
        const Radius.circular(18),
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
    Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 56)),
  );
}

void _drawBackground(Canvas c, Size s) {
  final rect = Offset.zero & s;
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bgTop, _bgBottom],
      ).createShader(rect),
  );
  // Soft light bloom, upper-left.
  c.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.7),
        radius: 0.9,
        colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
      ).createShader(rect),
  );
}

/// Draws the logo mark centred on the origin in 1024-design units.
void _drawMark(Canvas c, {bool mono = false}) {
  final gear = _gearPath();
  final fill = Paint()..isAntiAlias = true;
  final stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  if (mono) c.saveLayer(const Rect.fromLTWH(-600, -600, 1200, 1200), Paint());

  if (!mono) {
    // Orbit ring
    stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.28);
    c.drawCircle(Offset.zero, _ringR, stroke);
  }

  // Targets (drawn first so the gear overlaps the stems) -------------------
  void target(double deg, {required bool hazard}) {
    c
      ..save()
      ..rotate(deg * math.pi / 180);
    stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = mono ? Colors.white : _stem;
    c.drawLine(const Offset(_gearR - 40, 0), const Offset(_ringR, 0), stroke);
    stroke.strokeCap = StrokeCap.butt;

    c.translate(_ringR, 0);
    if (!hazard) {
      if (!mono) {
        c.drawCircle(
          Offset.zero,
          _ballR * 1.35,
          Paint()
            ..color = _ball.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
      }
      fill.color = mono ? Colors.white : _ball;
      c.drawCircle(Offset.zero, _ballR, fill);
      if (!mono) {
        fill.color = Colors.white.withValues(alpha: 0.9);
        c.drawCircle(const Offset(-12, -12), _ballR * 0.38, fill);
      }
    } else {
      const r = _ballR;
      final spike = Path()
        ..moveTo(r + 26, 0)
        ..lineTo(-r * 0.7, -r * 1.05)
        ..lineTo(-r * 0.7, r * 1.05)
        ..close();
      fill.color = mono ? Colors.white : _hazard;
      c.drawPath(spike, fill);
      if (!mono) {
        stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.85);
        c.drawPath(spike, stroke);
      }
    }
    c.restore();
  }

  target(-50, hazard: false);
  target(70, hazard: true);
  target(190, hazard: false);

  // Gear -------------------------------------------------------------------
  if (!mono) {
    c
      ..save()
      ..translate(0, 18);
    c.drawPath(
      gear,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    c.restore();
  }
  c.save();
  c.rotate(8 * math.pi / 180);
  fill.shader = mono
      ? null
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gearTop, _gearBottom],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: _gearR));
  fill.color = mono ? Colors.white : Colors.white;
  c.drawPath(gear, fill);
  fill.shader = null;
  if (!mono) {
    stroke
      ..strokeWidth = 11
      ..strokeJoin = StrokeJoin.round
      ..color = _gearEdge;
    c.drawPath(gear, stroke);
  }
  c.restore();

  // Hub: dark socket + glowing cyan core
  if (mono) {
    c.drawCircle(Offset.zero, 30, Paint()..blendMode = BlendMode.clear);
    c.restore();
  } else {
    fill.color = _gearBottom;
    c.drawCircle(Offset.zero, 38, fill);
    c.drawCircle(
      Offset.zero,
      26,
      Paint()
        ..color = _ball.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    fill.color = _ball;
    c.drawCircle(Offset.zero, 17, fill);
    fill.color = Colors.white.withValues(alpha: 0.9);
    c.drawCircle(const Offset(-5, -5), 6, fill);
  }
}

enum _Shape { square, rounded, circle }

Future<Uint8List> _png(
  int px, {
  bool background = true,
  bool mark = true,
  bool mono = false,
  double markScale = 1.0,
  _Shape shape = _Shape.square,
}) async {
  final size = Size(px.toDouble(), px.toDouble());
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);

  switch (shape) {
    case _Shape.rounded:
      c.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(px * 0.22)));
    case _Shape.circle:
      c.clipPath(Path()..addOval(Offset.zero & size));
    case _Shape.square:
      break;
  }
  if (background) _drawBackground(c, size);
  if (mark) {
    c
      ..save()
      ..translate(px / 2, px / 2)
      ..scale(px / 1024 * markScale);
    _drawMark(c, mono: mono);
    c.restore();
  }
  final img = await rec.endRecording().toImage(px, px);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Uint8List> _featureGraphic(ByteData blackFont, ByteData boldFont) async {
  final loaderBlack = FontLoader('RobotoBlack')..addFont(Future.value(blackFont));
  final loaderBold = FontLoader('RobotoBold')..addFont(Future.value(boldFont));
  await loaderBlack.load();
  await loaderBold.load();

  const w = 1024.0, h = 500.0;
  const size = Size(w, h);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  _drawBackground(c, size);

  // Decorative faint rings
  final ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = Colors.white.withValues(alpha: 0.10);
  for (final r in [330.0, 430.0, 540.0]) {
    c.drawCircle(const Offset(250, 250), r, ringPaint);
  }

  c
    ..save()
    ..translate(250, 250)
    ..scale(0.68);
  _drawMark(c);
  c.restore();

  void text(String t, String family, double fs, double y, {double spacing = 0, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: family,
          fontSize: fs,
          letterSpacing: spacing,
          color: color ?? Colors.white,
          shadows: const [Shadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(500, y));
  }

  text('GEAR SPIN', 'RobotoBlack', 88, 160, spacing: 1);
  text('TAP & HIT', 'RobotoBold', 50, 272, spacing: 12, color: const Color(0xFF14204D));

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void _write(String path, Uint8List bytes) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes);
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';

      // ---- Android legacy + round + adaptive layers ------------------------
      const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      for (final e in legacy.entries) {
        _write('$res/mipmap-${e.key}/ic_launcher.png', await _png(e.value, shape: _Shape.rounded, markScale: 1.18));
        _write('$res/mipmap-${e.key}/ic_launcher_round.png', await _png(e.value, shape: _Shape.circle, markScale: 1.1));
      }
      const adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
      for (final e in adaptive.entries) {
        _write('$res/mipmap-${e.key}/ic_launcher_foreground.png', await _png(e.value, background: false));
        _write('$res/mipmap-${e.key}/ic_launcher_monochrome.png', await _png(e.value, background: false, mono: true));
      }
      // Splash logo (shown centred on the launch background)
      _write('$res/drawable-nodpi/launch_logo.png', await _png(384, background: false, markScale: 1.0));

      // ---- Google Play Store ----------------------------------------------
      _write('store/play_store_icon_512.png', await _png(512, markScale: 1.18));
      final black = ByteData.sublistView(
          File('C:/dev/flutter/bin/cache/artifacts/material_fonts/roboto-black.ttf').readAsBytesSync());
      final bold = ByteData.sublistView(
          File('C:/dev/flutter/bin/cache/artifacts/material_fonts/roboto-bold.ttf').readAsBytesSync());
      _write('store/feature_graphic_1024x500.png', await _featureGraphic(black, bold));

      // ---- iOS -------------------------------------------------------------
      const ios = <String, int>{
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final e in ios.entries) {
        _write('ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}', await _png(e.value, markScale: 1.18));
      }

      // ---- Web -------------------------------------------------------------
      _write('web/favicon.png', await _png(32, shape: _Shape.rounded, markScale: 1.18));
      _write('web/icons/Icon-192.png', await _png(192, shape: _Shape.rounded, markScale: 1.18));
      _write('web/icons/Icon-512.png', await _png(512, shape: _Shape.rounded, markScale: 1.18));
      _write('web/icons/Icon-maskable-192.png', await _png(192));
      _write('web/icons/Icon-maskable-512.png', await _png(512));
    });
  });
}
