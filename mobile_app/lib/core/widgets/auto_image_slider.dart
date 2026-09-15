import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Professional Auto-Rotating Landscape Image Slideshow
/// Smoothly cross-fades role-specific authentic photography every 2 seconds.
class AutoImageSlider extends StatefulWidget {
  final String role;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final Duration rotationInterval;
  final Duration transitionDuration;

  const AutoImageSlider({
    super.key,
    required this.role,
    this.height = 160.0,
    this.borderRadius = 20.0,
    this.margin = const EdgeInsets.only(bottom: AppConstants.space16),
    this.rotationInterval = const Duration(seconds: 2),
    this.transitionDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AutoImageSlider> createState() => _AutoImageSliderState();
}

class _AutoImageSliderState extends State<AutoImageSlider> {
  Timer? _timer;
  int _currentIndex = 0;
  List<RoleImageItem> _images = [];

  @override
  void initState() {
    super.initState();
    _images = RoleImages.getImagesForRole(widget.role);
    _startAutoRotation();
  }

  @override
  void didUpdateWidget(covariant AutoImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _images = RoleImages.getImagesForRole(widget.role);
      _currentIndex = 0;
      _startAutoRotation();
    }
  }

  void _startAutoRotation() {
    _timer?.cancel();
    if (_images.length <= 1) return;

    _timer = Timer.periodic(widget.rotationInterval, (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
      _preloadNextImage();
    });
  }

  void _preloadNextImage() {
    if (_images.isEmpty || !mounted) return;
    final nextIndex = (_currentIndex + 1) % _images.length;
    final nextItem = _images[nextIndex];
    if (nextItem.url.isNotEmpty) {
      try {
        precacheImage(NetworkImage(nextItem.url), context).catchError((_) {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildImageWidget(BuildContext context, RoleImageItem item) {
    // If URL starts with assets/ or local fallback is provided
    if (item.url.startsWith('assets/')) {
      return Image.asset(
        item.url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: item.label,
        errorBuilder: (context, error, stackTrace) => _buildColorPlaceholder(context),
      );
    }

    return Image.network(
      item.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: item.label,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _buildFallbackImage(context, item);
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFallbackImage(context, item);
      },
    );
  }

  Widget _buildFallbackImage(BuildContext context, RoleImageItem item) {
    if (item.localAssetFallback.isNotEmpty) {
      return Image.asset(
        item.localAssetFallback,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildColorPlaceholder(context);
        },
      );
    }
    return _buildColorPlaceholder(context);
  }

  Widget _buildColorPlaceholder(BuildContext context) {
    final roleIcon = RoleImages.getRoleIcon(widget.role);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: context.primarySoftColor,
      alignment: Alignment.center,
      child: Icon(
        roleIcon,
        size: 48,
        color: context.colors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _images[_currentIndex % _images.length];

    return Container(
      width: double.infinity,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : context.borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Smooth Animated Cross-fade
            AnimatedSwitcher(
              duration: widget.transitionDuration,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: SizedBox(
                key: ValueKey<int>(_currentIndex),
                width: double.infinity,
                height: double.infinity,
                child: _buildImageWidget(context, currentItem),
              ),
            ),

            // Subtle bottom gradient overlay for readability & professional polish
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.60),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentItem.label,
                        key: ValueKey<String>('slider_label_text_${currentItem.label}'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Minimal indicator dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_images.length, (idx) {
                        final isSelected = idx == _currentIndex;
                        return Container(
                          width: isSelected ? 12 : 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isSelected
                                ? AppConstants.honeyAccent
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
