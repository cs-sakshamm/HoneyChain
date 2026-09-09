import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/global_app_bar.dart';

/// Screen to select Theme Mode (Light, Dark, System Default)
class ThemeSettingScreen extends StatelessWidget {
  const ThemeSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final currentMode = themeCtrl.themeMode;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: GlobalAppBar(
        showBackButton: true,
        titleText: context.tr('theme_settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space24),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                title: context.tr('light'),
                subtitle: context.tr('light_subtitle'),
                mode: ThemeMode.light,
                currentMode: currentMode,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
              ),
              Divider(height: 1, color: context.borderColor),
              _buildThemeOption(
                context,
                title: context.tr('dark'),
                subtitle: context.tr('dark_subtitle'),
                mode: ThemeMode.dark,
                currentMode: currentMode,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
              ),
              Divider(height: 1, color: context.borderColor),
              _buildThemeOption(
                context,
                title: context.tr('system_default'),
                subtitle: context.tr('system_default_subtitle'),
                mode: ThemeMode.system,
                currentMode: currentMode,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.system),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required VoidCallback onTap,
  }) {
    final isSelected = currentMode == mode;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? context.primaryDarkColor : context.textPrimaryColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: context.primaryDarkColor, size: 22)
          : Icon(Icons.circle_outlined, color: context.textMutedColor, size: 22),
      onTap: onTap,
    );
  }
}

