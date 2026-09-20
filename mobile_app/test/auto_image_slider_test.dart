import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/widgets/auto_image_slider.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  group('RoleImages Data Separation & Integrity Tests', () {
    test('Harvester role provides exactly 1 image with valid fallback', () {
      final images = RoleImages.getImagesForRole('HARVESTER');
      expect(images.length, equals(1));
      expect(images[0].url.isNotEmpty, isTrue);
      expect(images[0].label.isNotEmpty, isTrue);
      expect(images[0].localAssetFallback, equals('assets/images/beekeeping_hero.webp'));
    });

    test('Collection role provides exactly 1 image with valid fallback', () {
      final images = RoleImages.getImagesForRole('COLLECTION');
      expect(images.length, equals(1));
      expect(images[0].url.isNotEmpty, isTrue);
      expect(images[0].label.isNotEmpty, isTrue);
      expect(images[0].localAssetFallback, equals('assets/images/collection_processing_hero.webp'));
    });

    test('Lab role provides exactly 1 image with valid fallback', () {
      final images = RoleImages.getImagesForRole('LAB');
      expect(images.length, equals(1));
      expect(images[0].url.isNotEmpty, isTrue);
      expect(images[0].label.isNotEmpty, isTrue);
      expect(images[0].localAssetFallback, equals('assets/images/lab_testing_hero.webp'));
    });

    test('Packaging role returns exactly 1 relevant packaging hero image', () {
      final images = RoleImages.getImagesForRole('PACKAGING');
      expect(images.length, equals(1));
      expect(images[0].url.isNotEmpty, isTrue);
      expect(images[0].label.isNotEmpty, isTrue);
      expect(images[0].localAssetFallback, equals('assets/images/packaging_hero.jpeg'));
    });

    test('All 4 role images across all 4 roles are completely unique (no duplicates)', () {
      final allRoles = ['HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB_TESTER', 'PACKAGING'];
      final allUrls = <String>[];
      for (final role in allRoles) {
        final images = RoleImages.getImagesForRole(role);
        expect(images.length, equals(1));
        for (final item in images) {
          allUrls.add(item.url);
        }
      }
      expect(allUrls.length, equals(4));
      expect(allUrls.toSet().length, equals(4));
    });

    test('No bird, watermelon, tomato, leaf or unrelated imagery exist in role datasets', () {
      final allRoles = ['HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB_TESTER', 'PACKAGING'];
      final forbidden = ['watermelon', 'tomato', 'bird', 'avian', 'parrot', 'fruit', 'leaf', 'leaves', 'plant', 'vegetable'];
      for (final role in allRoles) {
        final images = RoleImages.getImagesForRole(role);
        for (final item in images) {
          for (final word in forbidden) {
            expect(item.url.toLowerCase().contains(word), isFalse, reason: 'URL must not contain $word');
            expect(item.label.toLowerCase().contains(word), isFalse, reason: 'Label must not contain $word');
            expect(item.localAssetFallback.toLowerCase().contains(word), isFalse, reason: 'Fallback must not contain $word');
          }
        }
      }
    });
  });

  group('AutoImageSlider Widget Tests', () {
    testWidgets('AutoImageSlider renders cleanly and displays hero label stably', (WidgetTester tester) async {
      final images = RoleImages.getImagesForRole('HARVESTER');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoImageSlider(
              role: 'HARVESTER',
            ),
          ),
        ),
      );

      // Initial frame
      expect(find.byType(AutoImageSlider), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[0].label}')), findsOneWidget);

      // Advance by 2 seconds - single image stays static and doesn't crash or cycle
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[0].label}')), findsOneWidget);
    });
  });
}
