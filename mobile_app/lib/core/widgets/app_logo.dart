import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Centralized, Reusable HoneyChain Brand Logo & Premium Wordmark
/// Features modern, clean, Pinterest-inspired geometric sans-serif typography
/// with finely tuned kerning, balanced visual weight, and perfect vertical alignment.
class HoneyChainLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool isDark;
  final String? subtitle;
  final TextStyle? textStyle;
  final MainAxisSize mainAxisSize;
  final Color? color;

  const HoneyChainLogo({
    super.key,
    this.size = 28.0,
    this.showWordmark = true,
    this.isDark = false,
    this.subtitle,
    this.textStyle,
    this.mainAxisSize = MainAxisSize.min,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeIsDark = isDark || Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.colors.primary;
    final textColor = color ?? context.textPrimaryColor;
    final subtitleColor = context.textSecondaryColor;

    // Geometric Hexagon + Chain Node Brand Mark
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HoneyChainLogoPainter(
          primaryColor: primaryColor,
          secondaryColor: themeIsDark ? Colors.white : context.textPrimaryColor,
        ),
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    final fontSize = size * 0.68;
    final letterSpacing = -fontSize * 0.035; // Fine-tuned optical kerning

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: size * 0.32),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Honey',
                    style: (textStyle ?? GoogleFonts.plusJakartaSans()).copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: letterSpacing,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: 'Chain',
                    style: (textStyle ?? GoogleFonts.plusJakartaSans()).copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: letterSpacing,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Backward-compatible alias for existing codebase usages
typedef AppLogo = HoneyChainLogo;

class _HoneyChainLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _HoneyChainLogoPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = w / 2;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Outer geometric flat-topped hexagon
    final Path hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60 - 30) * math.pi / 180;
      final double x = center.dx + (radius * 0.92) * math.cos(angle);
      final double y = center.dy + (radius * 0.92) * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    strokePaint.color = primaryColor;
    canvas.drawPath(hexPath, strokePaint);

    // 2. Inner geometric chain node / 'H' motif
    final double linkWidth = w * 0.36;
    final double linkHeight = h * 0.28;
    final double thickness = w * 0.08;

    final RRect leftNode = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - linkWidth * 0.32, center.dy),
        width: thickness * 1.5,
        height: linkHeight * 1.2,
      ),
      Radius.circular(thickness * 0.7),
    );

    final RRect rightNode = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + linkWidth * 0.32, center.dy),
        width: thickness * 1.5,
        height: linkHeight * 1.2,
      ),
      Radius.circular(thickness * 0.7),
    );

    final RRect centerBar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: linkWidth,
        height: thickness * 1.1,
      ),
      Radius.circular(thickness * 0.5),
    );

    fillPaint.color = primaryColor;
    canvas.drawRRect(leftNode, fillPaint);
    canvas.drawRRect(rightNode, fillPaint);

    fillPaint.color = secondaryColor;
    canvas.drawRRect(centerBar, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

