import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/localization/localization_service.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';
import 'package:mobile_app/features/hives/controllers/hive_controller.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';
import 'package:mobile_app/core/controllers/telemetry_alert_controller.dart';
import 'package:mobile_app/core/controllers/workflow_controller.dart';
import 'package:mobile_app/features/verification/controllers/verification_controller.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('HoneyChainApp renders cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    await tester.pumpAndSettle();

    // Verify App Name / Brand rendering
    expect(find.text(AppConstants.appName), findsWidgets);
  });
}
