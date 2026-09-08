import 'package:flutter/material.dart';

/// Renders the official 4-color Google "G" logo vector icon with exact paths
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({
    super.key,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double sx = w / 24.0;
    final double sy = h / 24.0;

    canvas.save();
    canvas.scale(sx, sy);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Red Top Arc
    paint.color = const Color(0xFFEA4335);
    final Path pRed = Path()
      ..moveTo(12.0, 5.0)
      ..cubicTo(14.05, 5.0, 15.89, 5.72, 17.33, 6.94)
      ..lineTo(20.73, 3.54)
      ..cubicTo(18.36, 1.34, 15.34, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.34, 2.68, 1.4, 6.6)
      ..lineTo(5.27, 9.61)
      ..cubicTo(6.17, 6.93, 8.84, 5.0, 12.0, 5.0);
    canvas.drawPath(pRed, paint);

    // 2. Yellow Left Arc
    paint.color = const Color(0xFFFBBC05);
    final Path pYellow = Path()
      ..moveTo(5.27, 9.61)
      ..cubicTo(4.79, 11.04, 4.5, 12.58, 4.5, 14.17)
      ..cubicTo(4.5, 15.76, 4.79, 17.3, 5.27, 18.73)
      ..lineTo(1.4, 21.74)
      ..cubicTo(0.51, 19.43, 0.0, 16.89, 0.0, 14.17)
      ..cubicTo(0.0, 11.45, 0.51, 8.91, 1.4, 6.6)
      ..lineTo(5.27, 9.61);
    canvas.drawPath(pYellow, paint);

    // 3. Green Bottom Arc
    paint.color = const Color(0xFF34A853);
    final Path pGreen = Path()
      ..moveTo(12.0, 23.33)
      ..cubicTo(15.22, 23.33, 18.23, 22.25, 20.47, 20.31)
      ..lineTo(16.74, 17.35)
      ..cubicTo(15.42, 18.25, 13.78, 18.83, 12.0, 18.83)
      ..cubicTo(8.84, 18.83, 6.17, 16.9, 5.27, 14.22)
      ..lineTo(1.4, 17.23)
      ..cubicTo(3.34, 21.15, 7.33, 23.83, 12.0, 23.83);
    canvas.drawPath(pGreen, paint);

    // 4. Blue Right Arc & Horizontal Bar
    paint.color = const Color(0xFF4285F4);
    final Path pBlue = Path()
      ..moveTo(23.49, 12.27)
      ..cubicTo(23.49, 11.48, 23.42, 10.73, 23.3, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.74)
      ..lineTo(18.52, 14.74)
      ..cubicTo(18.2, 16.34, 17.28, 17.65, 15.93, 18.55)
      ..lineTo(19.74, 21.5)
      ..cubicTo(22.01, 19.4, 23.49, 16.14, 23.49, 12.27);
    canvas.drawPath(pBlue, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
