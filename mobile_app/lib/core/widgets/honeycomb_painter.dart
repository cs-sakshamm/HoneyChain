import 'dart:math';

import 'package:flutter/material.dart';

/// A subtle background decoration pattern using hexagons (honeycomb).
class HoneycombBackgroundPainter extends CustomPainter {
  final Color color;
  final double hexagonRadius;
  final double strokeWidth;

  HoneycombBackgroundPainter({
    required this.color,
    this.hexagonRadius = 40.0,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Calculate dimensions
    final width = sqrt(3) * hexagonRadius;
    final height = 2 * hexagonRadius;
    final horizSpacing = width;
    final vertSpacing = 3 / 4 * height;

    final cols = (size.width / horizSpacing).ceil() + 1;
    final rows = (size.height / vertSpacing).ceil() + 1;

    for (int row = -1; row <= rows; row++) {
      for (int col = -1; col <= cols; col++) {
        double x = col * horizSpacing;
        double y = row * vertSpacing;

        // Stagger rows
        if (row % 2 != 0) {
          x += width / 2;
        }

        _drawHexagon(canvas, paint, Offset(x, y));
      }
    }
  }

  void _drawHexagon(Canvas canvas, Paint paint, Offset center) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i + (pi / 6); // Add pi/6 to point up/down
      final x = center.dx + hexagonRadius * cos(angle);
      final y = center.dy + hexagonRadius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
