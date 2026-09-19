import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/widgets/user_avatar.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';
import 'package:provider/provider.dart';

void main() {
  group('3-Tier Avatar Priority & Google Profile Picture Tests', () {
    test('UserProfile effectivePhotoUrl: Tier 1 (custom avatar) takes precedence over Tier 2 (Google photo)', () {
      const profile = UserProfile(
        name: 'Test Harvester',
        email: 'test@honeychain.io',
        phone: '1234567890',
        role: 'HARVESTER',
        avatarUrl: 'https://example.com/custom_avatar.jpg',
        googlePhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      expect(profile.effectivePhotoUrl, equals('https://example.com/custom_avatar.jpg'));
    });

    test('UserProfile effectivePhotoUrl: Tier 2 (Google photo) takes precedence when Tier 1 is null or empty', () {
      const profileWithNullAvatar = UserProfile(
        name: 'Test Lab',
        email: 'lab@honeychain.io',
        phone: '1234567890',
        role: 'LAB',
        avatarUrl: null,
        googlePhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      expect(profileWithNullAvatar.effectivePhotoUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));

      const profileWithEmptyAvatar = UserProfile(
        name: 'Test Lab',
        email: 'lab@honeychain.io',
        phone: '1234567890',
        role: 'LAB',
        avatarUrl: '   ',
        googlePhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      expect(profileWithEmptyAvatar.effectivePhotoUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
    });

    test('UserProfile effectivePhotoUrl: Falls back to null (Tier 3) when neither is set', () {
      const profileWithoutPhotos = UserProfile(
        name: 'Test Packaging',
        email: 'pkg@honeychain.io',
        phone: '1234567890',
        role: 'PACKAGING',
        avatarUrl: null,
        googlePhotoUrl: null,
      );

      expect(profileWithoutPhotos.effectivePhotoUrl, isNull);
      expect(profileWithoutPhotos.initial, equals('T'));
    });

    testWidgets('UserAvatar renders initial letter when effectivePhotoUrl is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthController()),
            ChangeNotifierProvider(create: (_) => UserController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Alex Honey',
                email: 'alex@example.com',
                photoUrl: null,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('A'), findsOneWidget);
    });
  });
}
