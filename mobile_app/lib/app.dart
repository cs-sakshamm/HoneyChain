import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/controllers/workflow_controller.dart';
import 'features/hives/controllers/hive_controller.dart';
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
import 'features/profile/controllers/user_controller.dart';
import 'features/notifications/critical_alert_modal.dart';

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
      builder: (context, child) {
        return CriticalAlertModalWrapper(child: child!);
      },
      home: const AuthRouter(),
    );
  }
}

/// Reactive router checking returning user authentication status
class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  String? _lastLoadedUserId;

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final userController = context.watch<UserController>();
    context.watch<LanguageController>();

    if (authController.selectedRole == null) {
      return const RoleSelectionScreen();
    }

    if (!authController.isAuthenticated) {
      return const LoginScreen();
    }

    // Automatically synchronize user profile + workflow data on login.
    // The token is now in AuthTokenStore, so REST calls authenticate properly;
    // receivers also pick up any requests created while they were offline.
    final currentUid = authController.currentUser?.uid ?? 'authenticated';
    if (_lastLoadedUserId != currentUid) {
      _lastLoadedUserId = currentUid;
      final workflowController = context.read<WorkflowController>();
      final hiveController = context.read<HiveController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userController.reloadProfile();
        workflowController.fetchAllData();
        // Hives are PostgreSQL-backed and need the fresh session token;
        // without this the dashboard can show a stale/other-user list.
        hiveController.setActiveBeekeeper(userController.user.id);
      });
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
