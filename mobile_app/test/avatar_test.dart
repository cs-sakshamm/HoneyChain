import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/widgets/user_avatar.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';
import 'package:provider/provider.dart';

void main() {
  group('User Profile & Avatar Priority Tests', () {
    test('Calculates first-letter initial correctly from name', () {
      const profile1 = UserProfile(
        name: 'Prabhakar Gupta',
        email: 'prabhakar@example.com',
        phone: '9876543210',
      );
      expect(profile1.initial, equals('P'));

      const profile2 = UserProfile(
        name: 'rahul Sharma',
        email: 'rahul@example.com',
        phone: '9876543210',
      );
      expect(profile2.initial, equals('R'));
    });

    test('Falls back to email initial when name is unavailable', () {
      const profileEmail = UserProfile(
        name: '',
        email: 'rahul@gmail.com',
        phone: '9876543210',
      );
      expect(profileEmail.initial, equals('R'));

      const profileZ = UserProfile(
        name: '',
        email: 'zackary@domain.org',
        phone: '9876543210',
      );
      expect(profileZ.initial, equals('Z'));
    });

    test('Two different beekeepers have distinct initials', () {
      const userA = UserProfile(
        name: 'Alice Wonder',
        email: 'alice@honey.com',
        phone: '1111111111',
      );
      const userB = UserProfile(
        name: 'Bob Miller',
        email: 'bob@honey.com',
        phone: '2222222222',
      );
      expect(userA.initial, isNot(equals(userB.initial)));
    });

    testWidgets('UserAvatar renders initial letter properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthController()),
            ChangeNotifierProvider(create: (_) => UserController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Prabhakar',
                email: 'prabhakar@honey.com',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('P'), findsOneWidget);
    });
  });
}
