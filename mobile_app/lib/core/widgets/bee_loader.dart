import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// HoneyChain flying-bee loading indicator.
///
/// Pure Flutter animation (no new dependencies): a small honey bee glides
/// along a gentle sine path leaving a fading dotted "buzz" trail. Theme-aware
/// (honey accent + current text colors) so it works in light and dark mode.
/// Used for API loading and authentication states in place of the old default
/// blue progress bar.
class BeeLoader extends StatefulWidget {
  final double size;
  final String? message;

  const BeeLoader({super.key, this.size = 64, this.message});

  @override
  State<BeeLoader> createState() => _BeeLoaderState();
}

class _BeeLoaderState extends State<BeeLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size * 2,
            height: widget.size * 1.4,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BeeTrailPainter(
                  progress: _controller.value,
                  trailColor: context.textMutedColor.withValues(alpha: isDark ? 0.35 : 0.45),
                ),
                child: Transform.translate(
                  offset: Offset(
                    math.sin(_controller.value * 2 * math.pi) * widget.size * 0.55,
                    math.sin(_controller.value * 4 * math.pi) * widget.size * 0.12,
                  ),
                  child: _BeeGlyph(size: widget.size * 0.42),
                ),
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppConstants.space12),
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact horizontal top loader: the bee flies edge-to-edge with a dotted
/// trail. Drop-in replacement for the old blue top loading bar.
class BeeTopLoader extends StatefulWidget {
  final double height;

  const BeeTopLoader({super.key, this.height = 40});

  @override
  State<BeeTopLoader> createState() => _BeeTopLoaderState();
}

class _BeeTopLoaderState extends State<BeeTopLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Smooth ping-pong: 0 -> 1 -> 0 across the lane.
          final t = _controller.value < 0.5 ? _controller.value * 2 : (1 - _controller.value) * 2;
          return CustomPaint(
            painter: _BeeLanePainter(
              progress: Curves.easeInOut.transform(t),
              trailColor: context.textMutedColor.withValues(alpha: 0.4),
            ),
            child: Align(
              alignment: Alignment(-1 + 2 * t, 0),
              child: const _BeeGlyph(size: 22),
            ),
          );
        },
      ),
    );
  }
}

/// The bee itself: honey body with dark stripes, two fluttering translucent
/// wings, subtle antennae. Clean and minimal — deliberately not cartoonish.
class _BeeGlyph extends StatelessWidget {
  final double size;

  const _BeeGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stripeColor = isDark ? const Color(0xFFFAFAFA) : AppConstants.primaryDark;
    final wingColor = (isDark ? Colors.white : AppConstants.primaryDark).withValues(alpha: 0.22);

    return SizedBox(
      width: size,
      height: size * 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Wings
          Positioned(
            top: -size * 0.18,
            left: size * 0.12,
            child: _Wing(color: wingColor, size: size * 0.4),
          ),
          Positioned(
            top: -size * 0.18,
            left: size * 0.42,
            child: _Wing(color: wingColor, size: size * 0.4),
          ),
          // Body
          Center(
            child: Container(
              width: size * 0.92,
              height: size * 0.58,
              decoration: BoxDecoration(
                color: AppConstants.honeyAccent,
                borderRadius: BorderRadius.circular(size),
                border: Border.all(color: stripeColor.withValues(alpha: 0.85), width: 1),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stripe(color: stripeColor, width: size * 0.10, height: size * 0.5),
                  SizedBox(width: size * 0.10),
                  _Stripe(color: stripeColor, width: size * 0.10, height: size * 0.5),
                ],
              ),
            ),
          ),
          // Stinger
          Positioned(
            right: -size * 0.08,
            top: size * 0.40,
            child: Container(
              width: size * 0.14,
              height: 2,
              color: stripeColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stripe extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const _Stripe({required this.color, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(width)),
    );
  }
}

class _Wing extends StatelessWidget {
  final Color color;
  final double size;

  const _Wing({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Dotted buzz trail behind the bee (drawn behind the body, fading out).
class _BeeTrailPainter extends CustomPainter {
  final double progress;
  final Color trailColor;

  _BeeTrailPainter({required this.progress, required this.trailColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = trailColor;
    const dots = 4;
    for (var i = 1; i <= dots; i++) {
      final phase = (progress - i * 0.05) % 1.0;
      final x = size.width / 2 + math.sin(phase * 2 * math.pi) * size.width * 0.275;
      final y = size.height / 2 + math.sin(phase * 4 * math.pi) * size.height * 0.12 - i * 2;
      canvas.drawCircle(Offset(x, y), 1.6 * (1 - i / (dots + 1)) + 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(_BeeTrailPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trailColor != trailColor;
}

/// Straight flight lane with trail for the top-loader variant.
class _BeeLanePainter extends CustomPainter {
  final double progress; // 0..1, left -> right
  final Color trailColor;

  _BeeLanePainter({required this.progress, required this.trailColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = trailColor;
    final beeX = size.width * progress;
    final movingRight = progress > 0.02;
    for (var i = 1; i <= 5; i++) {
      final dx = beeX - (movingRight ? 1 : -1) * i * 10;
      if (dx < 4 || dx > size.width - 4) continue;
      final y = size.height / 2 + math.sin((beeX - dx) / 18) * 3;
      canvas.drawCircle(Offset(dx, y), 1.6 * (1 - i / 6) + 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(_BeeLanePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trailColor != trailColor;
}
