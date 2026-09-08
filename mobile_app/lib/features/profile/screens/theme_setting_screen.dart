import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
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
      backgroundColor: AppConstants.background,
      appBar: const GlobalAppBar(
        showBackButton: true,
        titleText: 'Theme Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space24),
        child: Container(
          decoration: BoxDecoration(
            color: AppConstants.surface,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            border: Border.all(color: AppConstants.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                title: 'Light',
                subtitle: 'Always clean light background',
                mode: ThemeMode.light,
                currentMode: currentMode,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
              ),
              const Divider(height: 1),
              _buildThemeOption(
                context,
                title: 'Dark',
                subtitle: 'Dark background for high contrast',
                mode: ThemeMode.dark,
                currentMode: currentMode,
                onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
              ),
              const Divider(height: 1),
              _buildThemeOption(
                context,
                title: 'System Default',
                subtitle: 'Match your phone system appearance',
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
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppConstants.primaryDark : AppConstants.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppConstants.primaryDark, size: 22)
          : const Icon(Icons.circle_outlined, color: AppConstants.textMuted, size: 22),
      onTap: onTap,
    );
  }
}
