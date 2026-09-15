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
    test('Harvester role returns exactly 5 unique relevant beekeeping images', () {
      final images = RoleImages.getImagesForRole('HARVESTER');
      expect(images.length, equals(5));
      expect(images.every((item) => item.url.isNotEmpty), isTrue);
      expect(images.every((item) => item.label.isNotEmpty), isTrue);
      expect(images.every((item) => item.localAssetFallback == 'assets/images/beekeeping_hero.jpg'), isTrue);
      final uniqueUrls = images.map((i) => i.url).toSet();
      expect(uniqueUrls.length, equals(5));
    });

    test('Collection & Processing role returns exactly 5 unique relevant processing images', () {
      final images = RoleImages.getImagesForRole('COLLECTOR_PROCESSOR');
      expect(images.length, equals(5));
      expect(images.every((item) => item.url.isNotEmpty), isTrue);
      expect(images.every((item) => item.label.isNotEmpty), isTrue);
      expect(images.every((item) => item.localAssetFallback == 'assets/images/collection_processing_hero.jpg'), isTrue);
      final uniqueUrls = images.map((i) => i.url).toSet();
      expect(uniqueUrls.length, equals(5));
    });

    test('Lab Tester role returns exactly 5 unique relevant lab testing images', () {
      final images = RoleImages.getImagesForRole('LAB_TESTER');
      expect(images.length, equals(5));
      expect(images.every((item) => item.url.isNotEmpty), isTrue);
      expect(images.every((item) => item.label.isNotEmpty), isTrue);
      expect(images.every((item) => item.localAssetFallback == 'assets/images/lab_testing_hero.jpg'), isTrue);
      final uniqueUrls = images.map((i) => i.url).toSet();
      expect(uniqueUrls.length, equals(5));
    });

    test('Packaging role returns exactly 5 unique relevant packaging images', () {
      final images = RoleImages.getImagesForRole('PACKAGING');
      expect(images.length, equals(5));
      expect(images.every((item) => item.url.isNotEmpty), isTrue);
      expect(images.every((item) => item.label.isNotEmpty), isTrue);
      expect(images.every((item) => item.localAssetFallback == 'assets/images/packaging_hero.jpg'), isTrue);
      final uniqueUrls = images.map((i) => i.url).toSet();
      expect(uniqueUrls.length, equals(5));
    });

    test('All 20 role images across all 4 roles are completely unique (no duplicates)', () {
      final allRoles = ['HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB_TESTER', 'PACKAGING'];
      final allUrls = <String>[];
      for (final role in allRoles) {
        final images = RoleImages.getImagesForRole(role);
        expect(images.length, equals(5));
        for (final item in images) {
          allUrls.add(item.url);
        }
      }
      expect(allUrls.length, equals(20));
      expect(allUrls.toSet().length, equals(20));
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
    testWidgets('AutoImageSlider renders cleanly and displays initial label', (WidgetTester tester) async {
      final images = RoleImages.getImagesForRole('HARVESTER');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoImageSlider(
              role: 'HARVESTER',
              rotationInterval: Duration(seconds: 2),
              transitionDuration: Duration(milliseconds: 300),
            ),
          ),
        ),
      );

      // Initial frame
      expect(find.byType(AutoImageSlider), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[0].label}')), findsOneWidget);

      // Advance by 2 seconds (rotation interval) + 300ms transition
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));

      // Should have advanced to image 2
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[1].label}')), findsOneWidget);

      // Advance by another 2 seconds + 300ms transition
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));

      // Should have advanced to image 3
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[2].label}')), findsOneWidget);
    });

    testWidgets('AutoImageSlider loops through all images smoothly', (WidgetTester tester) async {
      final images = RoleImages.getImagesForRole('LAB_TESTER');
      final totalImages = images.length; // 6 images

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoImageSlider(
              role: 'LAB_TESTER',
              rotationInterval: Duration(seconds: 2),
              transitionDuration: Duration(milliseconds: 300),
            ),
          ),
        ),
      );

      expect(find.byKey(ValueKey<String>('slider_label_text_${images[0].label}')), findsOneWidget);

      // Step through each subsequent image
      for (int i = 1; i < totalImages; i++) {
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(ValueKey<String>('slider_label_text_${images[i].label}')), findsOneWidget);
      }

      // Final step loops back to first image
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(ValueKey<String>('slider_label_text_${images[0].label}')), findsOneWidget);
    });
  });
}
