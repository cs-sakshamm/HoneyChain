import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/localization/localization_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/auth_controller.dart';
import 'features/hives/controllers/hive_controller.dart';
import 'features/profile/controllers/user_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProvider<HiveController>(
          create: (_) => HiveController(),
        ),
        ChangeNotifierProvider<LanguageController>(
          create: (_) => LanguageController(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
        ChangeNotifierProvider<UserController>(
          create: (_) => UserController(),
        ),
      ],
      child: const HoneyChainApp(),
    ),
  );
}
