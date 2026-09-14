import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/localization/localization_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/auth_controller.dart';
import 'features/authentication/login_screen.dart';
import 'features/authentication/role_selection_screen.dart';
import 'features/collection/collection_navigation_screen.dart';
import 'features/lab/lab_navigation_screen.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'features/packaging/packaging_navigation_screen.dart';

/// Root HoneyChain Mobile Application
class HoneyChainApp extends StatelessWidget {
  const HoneyChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    context.watch<LanguageController>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      home: const AuthRouter(),
    );
  }
}

/// Reactive router checking returning user authentication status
class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    context.watch<LanguageController>();

    if (authController.selectedRole == null) {
      return const RoleSelectionScreen();
    }

    if (!authController.isAuthenticated) {
      return const LoginScreen();
    }

    switch (authController.selectedRole) {
      case UserRole.harvester:
        return const MainNavigationScreen();
      case UserRole.collectionProcessing:
        return const CollectionNavigationScreen();
      case UserRole.labTesting:
        return const LabNavigationScreen();
      case UserRole.packaging:
        return const PackagingNavigationScreen();
      default:
        return const RoleSelectionScreen();
    }
  }
}
