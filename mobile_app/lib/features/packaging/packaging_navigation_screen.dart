import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';


import '../../core/localization/localization_service.dart';
import '../../core/theme/app_theme.dart';

import '../profile/screens/profile_screen.dart';
import 'screens/packaging_dashboard_screen.dart';
import 'screens/packaging_history_screen.dart';

/// Navigation Screen for the Packaging Role
class PackagingNavigationScreen extends StatefulWidget {
  const PackagingNavigationScreen({super.key});

  @override
  State<PackagingNavigationScreen> createState() => _PackagingNavigationScreenState();
}

class _PackagingNavigationScreenState extends State<PackagingNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isNavVisible = true;
  Timer? _idleTimer;

  final List<Widget> _pages = const [
    PackagingDashboardScreen(),
    PackagingHistoryScreen(),
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

    final surfaceColor = context.surfaceColor;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      extendBody: true,
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
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Center(
              heightFactor: 1.0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                height: 52,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: context.textPrimaryColor.withValues(
                          alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.inventory_2_outlined,
                      activeIcon: Icons.inventory_2_rounded,
                      label: context.tr('batches'),
                      isSelected: _currentIndex == 0,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.history_outlined,
                      activeIcon: Icons.history_rounded,
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
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    final activeColor = context.textPrimaryColor;
    final inactiveColor = context.textMutedColor;
    final pillBg = isSelected ? context.primarySoftColor : Colors.transparent;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _showNav();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }
}
