import 'package:flutter/material.dart';

import '../../domain/skin.dart';

/// Comet icon of a skin (used by shop tiles).
class SkinPreview extends StatelessWidget {
  const SkinPreview({super.key, required this.skin});

  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SkinPainter(skin), size: Size.infinite);
  }
}

class _SkinPainter extends CustomPainter {
  _SkinPainter(this.skin);

  final Skin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final head = Offset(size.width * 0.70, size.height * 0.30);
    final tail = Offset(size.width * 0.20, size.height * 0.80);

    // Tail: fades out towards the back.
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..shader = LinearGradient(
          colors: [skin.trail.withValues(alpha: 0), skin.trail.withValues(alpha: 0.9)],
        ).createShader(Rect.fromPoints(tail, head)),
    );

    // A few sparkles along the tail.
    final sparkle = Paint()..color = skin.glow.withValues(alpha: 0.7);
    for (final t in const [0.25, 0.45, 0.62]) {
      final p = Offset.lerp(tail, head, t)!;
      canvas.drawCircle(p + Offset(6 - t * 10, -6 + t * 8), 1.6, sparkle);
    }

    canvas.drawCircle(
      head,
      12,
      Paint()
        ..color = skin.glow.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(head, 7, Paint()..color = skin.core);
  }

  @override
  bool shouldRepaint(_SkinPainter oldDelegate) => oldDelegate.skin != skin;
}
