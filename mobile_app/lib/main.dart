import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/controllers/telemetry_alert_controller.dart';
import 'core/controllers/workflow_controller.dart';
import 'core/localization/localization_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/auth_controller.dart';
import 'features/hives/controllers/hive_controller.dart';
import 'features/profile/controllers/user_controller.dart';
import 'features/verification/controllers/verification_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

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
        ChangeNotifierProvider<VerificationController>(
          create: (_) => VerificationController(),
        ),
        ChangeNotifierProvider<WorkflowController>(
          create: (_) => WorkflowController(),
        ),
        ChangeNotifierProvider<TelemetryAlertController>(
          create: (_) => TelemetryAlertController(),
        ),
      ],
      child: const HoneyChainApp(),
    ),
  );
}
