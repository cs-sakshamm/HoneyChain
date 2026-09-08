import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Authentication Screen renders cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: const HoneyChainApp(),
      ),
    );

    // Verify App Name & Login Button
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.loginButtonText), findsOneWidget);
  });
}
