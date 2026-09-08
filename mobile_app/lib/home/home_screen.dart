import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_logo.dart';
import '../features/authentication/auth_controller.dart';

/// Senior Product Designer Business Dashboard & Navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppConstants.logoutTitle),
          content: const Text(
            AppConstants.logoutSubtitle,
            style: TextStyle(fontSize: 14, color: AppConstants.textSecondary),
          ),
          actions: [
            AppButton(
              text: AppConstants.logoutCancel,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: AppConstants.logoutConfirm,
              variant: AppButtonVariant.primary,
              width: 110,
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AuthController>().signOut();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    final displayName = user?.displayName ?? 'Acme Logistics Inc.';
    final email = user?.email ?? 'operations@acmelogistics.com';

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: AppConstants.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: AppConstants.space24,
        title: const AppLogo(
          size: 28,
          showWordmark: true,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppConstants.textSecondary, size: 20),
            tooltip: 'Log Out',
            onPressed: () => _showLogoutDialog(context),
          ),
          const SizedBox(width: AppConstants.space12),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(displayName, email),
          _buildActivityTab(),
          _buildReportsTab(),
          _buildProfileTab(displayName, email),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppConstants.surface,
          border: Border(top: BorderSide(color: AppConstants.border, width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppConstants.surface,
          selectedItemColor: AppConstants.primaryDark,
          unselectedItemColor: AppConstants.textMuted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // Tab 1: Home Dashboard Overview
  Widget _buildHomeTab(String displayName, String email) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business Summary Card
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppConstants.primarySoft,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space24),

          const Text(
            'Operational Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.space12),

          // KPI Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  label: 'Active Shipments',
                  value: '24',
                  change: '+12% vs last week',
                  isPositive: true,
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: _buildMetricCard(
                  label: 'Inventory Units',
                  value: '1,420',
                  change: 'Stable',
                  isPositive: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space24),

          const Text(
            'Recent Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.space12),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActivityTile(
                  title: 'Batch #8920 In Transit',
                  subtitle: 'Dispatched from Hub A • ETA 2 hrs',
                  time: '10m ago',
                  icon: Icons.local_shipping_outlined,
                ),
                const Divider(height: 1),
                _buildActivityTile(
                  title: 'Order Verification Confirmed',
                  subtitle: 'Supplier ID #4429 verified via Smart Contract',
                  time: '1h ago',
                  icon: Icons.verified_outlined,
                ),
                const Divider(height: 1),
                _buildActivityTile(
                  title: 'Warehouse Restock Received',
                  subtitle: '500 Units added to Stock Room B',
                  time: '3h ago',
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Activity Log
  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space24),
      children: [
        const Text(
          'Activity Log',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppConstants.space16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildActivityTile(
                title: 'Audit Log Exported',
                subtitle: 'Generated monthly compliance report',
                time: 'Yesterday',
                icon: Icons.assignment_outlined,
              ),
              const Divider(height: 1),
              _buildActivityTile(
                title: 'New Carrier Added',
                subtitle: 'Express Logistics Corp verified',
                time: 'Sep 06',
                icon: Icons.add_business_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 3: Reports
  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space24),
      children: [
        const Text(
          'Supply Chain Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppConstants.space16),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'On-Time Delivery Rate',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AppConstants.space8),
              Text(
                '98.4%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.success,
                ),
              ),
              SizedBox(height: AppConstants.space4),
              Text(
                'Top 5% efficiency rating across regional hubs.',
                style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 4: Profile & Settings
  Widget _buildProfileTab(String displayName, String email) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppConstants.space4),
              Text(
                email,
                style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
              ),
              const SizedBox(height: AppConstants.space16),
              const Divider(),
              const SizedBox(height: AppConstants.space12),
              AppButton(
                text: 'Log Out of Account',
                variant: AppButtonVariant.outlined,
                onPressed: () => _showLogoutDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String change,
    required bool isPositive,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppConstants.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppConstants.space4),
          Text(
            change,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isPositive ? AppConstants.success : AppConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.space16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.textSecondary),
          const SizedBox(width: AppConstants.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
