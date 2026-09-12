import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/localization_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/honeycomb_painter.dart';
import '../profile/controllers/user_controller.dart';
import 'auth_controller.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          // Background honeycomb decoration
          Positioned.fill(
            child: CustomPaint(
              painter: HoneycombBackgroundPainter(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.03)
                    : AppConstants.primaryDark.withValues(alpha: 0.05),
                hexagonRadius: 60,
                strokeWidth: 1.5,
              ),
            ),
          ),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 840;
                
                return Column(
                  children: [
                    // Top header with logo and controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppLogo(size: 28, showWordmark: true),
                          Row(
                            children: [
                              _ThemeToggle(),
                              const SizedBox(width: 12),
                              _LanguageSelector(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Main content
                    Expanded(
                      child: isDesktop
                          ? _buildDesktopLayout(context, constraints)
                          : _buildMobileLayout(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('select_your_role'),
                    style: GoogleFonts.manrope(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('choose_role_subtitle'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: context.textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildRoleGrid(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            context.tr('select_your_role'),
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('choose_role_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: context.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildRoleGrid(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRoleGrid(BuildContext context) {
    final roles = [
      _RoleItem(
        role: UserRole.harvester,
        titleKey: 'harvester',
        descKey: 'harvester_desc',
        icon: Icons.agriculture_rounded,
      ),
      _RoleItem(
        role: UserRole.collectionProcessing,
        titleKey: 'collection_processing',
        descKey: 'collection_desc',
        icon: Icons.local_shipping_rounded,
      ),
      _RoleItem(
        role: UserRole.labTesting,
        titleKey: 'lab_testing',
        descKey: 'lab_desc',
        icon: Icons.science_rounded,
      ),
      _RoleItem(
        role: UserRole.packaging,
        titleKey: 'packaging',
        descKey: 'packaging_desc',
        icon: Icons.inventory_2_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: roles.length,
      itemBuilder: (context, index) {
        return _RoleCard(item: roles[index]);
      },
    );
  }
}

class _RoleItem {
  final UserRole role;
  final String titleKey;
  final String descKey;
  final IconData icon;

  _RoleItem({
    required this.role,
    required this.titleKey,
    required this.descKey,
    required this.icon,
  });
}

class _RoleCard extends StatelessWidget {
  final _RoleItem item;

  const _RoleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: () {
        context.read<AuthController>().setRole(item.role);
        String roleStr = 'HARVESTER';
        switch (item.role) {
          case UserRole.harvester:
            roleStr = 'HARVESTER';
            break;
          case UserRole.collectionProcessing:
            roleStr = 'COLLECTOR_PROCESSOR';
            break;
          case UserRole.labTesting:
            roleStr = 'LAB';
            break;
          case UserRole.packaging:
            roleStr = 'PACKAGING';
            break;
        }
        context.read<UserController>().switchRole(roleStr);
      },
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.primarySoftColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : context.borderColor,
                ),
              ),
              child: Icon(
                item.icon,
                size: 32,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr(item.titleKey),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(item.descKey),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageController>(
      builder: (context, langCtrl, _) {
        return InkWell(
          onTap: () => _showLanguagePickerModal(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded, size: 16, color: context.textSecondaryColor),
                const SizedBox(width: 6),
                Text(
                  langCtrl.currentLanguage.nativeName,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.textSecondaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguagePickerModal(BuildContext context) {
    // We can reuse the same modal logic from LoginScreen, or copy a simplified version.
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Consumer<LanguageController>(
            builder: (context, langCtrl, _) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          langCtrl.tr('select_language'),
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: LanguageController.supportedLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = LanguageController.supportedLanguages[index];
                        final isSelected = lang.code == langCtrl.currentLanguageCode;

                        return Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          onTap: () {
                            langCtrl.setLanguage(lang.code);
                            Navigator.pop(context);
                          },
                          title: Text(
                            lang.nativeName,
                            style: GoogleFonts.manrope(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? context.primaryDarkColor : context.textPrimaryColor,
                            ),
                          ),
                          subtitle: Text(
                            lang.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.textSecondaryColor,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: context.primaryDarkColor)
                              : null,
                        ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isDark = themeController.themeMode == ThemeMode.dark ||
        (themeController.themeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    return InkWell(
      onTap: () {
        themeController.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 18,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}
