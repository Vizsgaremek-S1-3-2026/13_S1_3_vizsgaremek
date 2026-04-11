import 'package:flutter/material.dart';
import 'dart:math' as math;

class SubtleTexturePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double spacing;
  final double dotSize;

  SubtleTexturePainter({
    required this.color,
    this.opacity = 0.08,
    this.spacing = 18.0,
    this.dotSize = 1.3,
    this.isHovered = false,
  });

  final bool isHovered;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw a grid of Dots with left-to-right gradient
    for (double x = 0; x < size.width; x += spacing) {
      // Calculate horizontal progression (0.1 to 1.0)
      final double horizontalFactor = 0.1 + (0.9 * (x / size.width));

      // Hover boost: more visible when hovered
      final double hoverFactor = isHovered ? 1.8 : 1.0;
      final double finalOpacity = (opacity * horizontalFactor * hoverFactor)
          .clamp(0.0, 1.0);

      final dotPaint = Paint()
        ..color = color.withOpacity(finalOpacity)
        ..style = PaintingStyle.fill;

      for (double y = 0; y < size.height; y += spacing) {
        double offsetX = (y / spacing).floor() % 2 == 0 ? 0 : spacing / 2;

        // If hovered, slightly larger dots for "reaction"
        double finalDotSize = isHovered ? dotSize * 1.2 : dotSize;

        canvas.drawCircle(Offset(x + offsetX, y), finalDotSize, dotPaint);
      }
    }

    // 2. Add subtle "Noise" texture (kept but influenced by hover)
    final noisePaint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 400; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 0.8 + 0.2;

      double noiseOpacity = opacity * 0.3 * random.nextDouble();
      if (isHovered) noiseOpacity *= 1.5;

      noisePaint.color = color.withOpacity(noiseOpacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r, noisePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SubtleTexturePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.spacing != spacing ||
        oldDelegate.isHovered != isHovered;
  }
}
