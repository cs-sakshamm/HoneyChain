import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/auth_controller.dart';
import 'features/authentication/login_screen.dart';
import 'home/home_screen.dart';

/// Root HoneyChain Mobile Application
class HoneyChainApp extends StatelessWidget {
  const HoneyChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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

    if (authController.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
