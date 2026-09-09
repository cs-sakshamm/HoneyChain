import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../hives/screens/add_edit_hive_screen.dart';
import '../hives/screens/all_hives_screen.dart';
import '../hives/screens/home_dashboard_screen.dart';
import '../profile/screens/profile_screen.dart';

/// Main Post-Login Shell with Pinterest-inspired Centered Bottom Navigation
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0; // 0: Home, 1: Search (Hives), 2: Profile (Notifications modal is popover)
  bool _isNavVisible = true;
  Timer? _idleTimer;

  final List<Widget> _pages = const [
    HomeDashboardScreen(),
    AllHivesScreen(),
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

  void _showNotificationsSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: AppConstants.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    modalContext.tr('notifications'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.primarySoftColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '3 New',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildNotificationItem(
                context,
                icon: Icons.health_and_safety_rounded,
                iconColor: AppConstants.success,
                title: 'Hive #4 Inspection Clean',
                time: '10 mins ago',
              ),
              const Divider(height: 16),
              _buildNotificationItem(
                context,
                icon: Icons.inventory_2_rounded,
                iconColor: AppConstants.primary,
                title: 'Honey Yield Recorded: 45 kg',
                time: '2 hours ago',
              ),
              const Divider(height: 16),
              _buildNotificationItem(
                context,
                icon: Icons.warning_amber_rounded,
                iconColor: AppConstants.warning,
                title: 'Hive #12 Needs Attention',
                time: 'Yesterday',
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: context.textMutedColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
    context.watch<LanguageController>();

    final scaffoldBg = context.scaffoldBg;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Center(
              heightFactor: 1.0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                height: 56,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Home Tab
                    _buildPinterestNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: context.tr('home'),
                      isSelected: _currentIndex == 0,
                      onTap: () {
                        setState(() {
                          _currentIndex = 0;
                          _showNav();
                        });
                      },
                    ),
                    // 2. All Hives Tab
                    _buildPinterestNavItem(
                      index: 1,
                      icon: Icons.hive_outlined,
                      activeIcon: Icons.hive_rounded,
                      label: context.tr('hives'),
                      isSelected: _currentIndex == 1,
                      onTap: () {
                        setState(() {
                          _currentIndex = 1;
                          _showNav();
                        });
                      },
                    ),
                    // 3. Create Button (Pinterest (+) center pill)
                    _buildCreateNavItem(
                      context,
                      onTap: () {
                        _showNav();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEditHiveScreen(),
                          ),
                        );
                      },
                    ),
                    // 4. Notifications Button
                    _buildPinterestNavItem(
                      index: 3,
                      icon: Icons.notifications_none_rounded,
                      activeIcon: Icons.notifications_rounded,
                      label: context.tr('notifications'),
                      isSelected: false,
                      onTap: () => _showNotificationsSheet(context),
                    ),
                    // 5. Profile Tab
                    _buildPinterestNavItem(
                      index: 2,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: context.tr('profile'),
                      isSelected: _currentIndex == 2,
                      onTap: () {
                        setState(() {
                          _currentIndex = 2;
                          _showNav();
                        });
                      },
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

  Widget _buildPinterestNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = context.textPrimaryColor;
    final inactiveColor = context.textMutedColor;
    final pillBg = isSelected ? context.primarySoftColor : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppConstants.primaryDark : inactiveColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNavItem(BuildContext context, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppConstants.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

