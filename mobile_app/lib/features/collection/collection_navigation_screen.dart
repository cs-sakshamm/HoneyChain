import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/localization/localization_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/global_app_bar.dart';
import '../profile/screens/profile_screen.dart';
import 'screens/collection_dashboard_screen.dart';
import 'screens/collection_history_screen.dart';

/// Minimal 3-Tab Collection & Processing Navigation with Frosted Floating Pill Dock
class CollectionNavigationScreen extends StatefulWidget {
  const CollectionNavigationScreen({super.key});

  @override
  State<CollectionNavigationScreen> createState() => _CollectionNavigationScreenState();
}

class _CollectionNavigationScreenState extends State<CollectionNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0; // 0: Requests, 1: History, 2: Profile
  bool _isNavVisible = true;
  Timer? _idleTimer;

  final List<Widget> _pages = const [
    CollectionDashboardScreen(),
    CollectionHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showNav();
    }
  }

  void _showNav() {
    _idleTimer?.cancel();
    if (!_isNavVisible && mounted) {
      setState(() => _isNavVisible = true);
    }
  }

  void _hideNav() {
    _idleTimer?.cancel();
    if (_isNavVisible && mounted) {
      setState(() => _isNavVisible = false);
    }
  }

  void _scheduleIdleAutoShow() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;

    if (metrics.maxScrollExtent <= 10 || metrics.pixels <= 10) {
      _showNav();
      return false;
    }

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _hideNav();
        _scheduleIdleAutoShow();
      } else if (notification.direction == ScrollDirection.forward) {
        _showNav();
      }
    } else if (notification is ScrollEndNotification) {
      _scheduleIdleAutoShow();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      extendBody: true,
      appBar: const GlobalAppBar(),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.4),
        child: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              heightFactor: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E).withValues(alpha: 0.85)
                          : context.surfaceColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : context.borderColor.withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: Icons.inbox_outlined,
                          activeIcon: Icons.inbox_rounded,
                          label: context.tr('requests'),
                          isSelected: _currentIndex == 0,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: Icons.swap_horiz_rounded,
                          activeIcon: Icons.swap_horiz_rounded,
                          label: context.tr('history'),
                          isSelected: _currentIndex == 1,
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: context.tr('profile'),
                          isSelected: _currentIndex == 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = context.textPrimaryColor;
    final inactiveColor = context.textMutedColor;
    final pillBg = isSelected
        ? (isDark ? Colors.white.withValues(alpha: 0.15) : context.primarySoftColor)
        : Colors.transparent;

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
              _showNav();
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      key: ValueKey<bool>(isSelected),
                      size: 22,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            label,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: activeColor,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
