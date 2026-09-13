import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/hives/models/hive_model.dart';

void main() {
  group('Hive Model Dynamic Calculations Test Suite', () {
    test('Calculates production metrics correctly', () {
      final hive = Hive(
        id: 'test_1',
        name: 'Test Hive',
        hiveCode: 'H-999',
        apiaryLocation: 'Test Apiary',
        hiveType: 'Langstroth',
        dateAdded: DateTime(2026, 1, 1),
        queenStatus: 'Mated',
        totalFrames: 10,
        broodFrames: 6,
        colonyStrength: 'Strong',
        queenAgeMonths: 12,
        beeBreed: 'Italian',
        expectedProductionKg: 35.0,
        previousYearProductionKg: 25.0,
        currentYearProductionKg: 28.0,
        honeyType: 'Wildflower',
        lastInspectionDate: DateTime(2026, 9, 1),
        miteStatus: 'Low',
        diseaseStatus: 'None',
        feedingRequired: false,
        queenCondition: 'Excellent',
        overallHealth: 'Healthy',
        notes: 'Test notes',
        updatedAt: DateTime(2026, 9, 1),
      );

      expect(hive.productionDifference, equals(3.0));
      expect(hive.productionChangePercentage, closeTo(12.0, 0.01));
      expect(hive.remainingExpectedProductionKg, equals(7.0));
      expect(hive.occupiedFrameRatio, equals('6 / 10'));
      expect(hive.occupiedFramePercentage, equals(60.0));
      expect(hive.isHealthy, isTrue);
      expect(hive.isQueenHealthy, isTrue);
      expect(hive.nextInspectionDate, equals(DateTime(2026, 9, 15)));
    });

    test('Serializes to and deserializes from JSON correctly with userId', () {
      final original = Hive(
        id: 'test_json',
        userId: 'user_beekeeper_123',
        name: 'JSON Hive',
        hiveCode: 'H-123',
        apiaryLocation: 'East Field',
        hiveType: 'Top-Bar',
        dateAdded: DateTime(2026, 5, 10),
        queenStatus: 'Re-queened',
        totalFrames: 8,
        broodFrames: 4,
        colonyStrength: 'Moderate',
        queenAgeMonths: 6,
        beeBreed: 'Carniolan',
        expectedProductionKg: 40.0,
        previousYearProductionKg: 30.0,
        currentYearProductionKg: 35.0,
        honeyType: 'Clover',
        lastInspectionDate: DateTime(2026, 8, 20),
        miteStatus: 'Medium',
        diseaseStatus: 'None',
        feedingRequired: true,
        queenCondition: 'Good',
        overallHealth: 'Needs Attention',
        notes: 'Feeding syrup',
        updatedAt: DateTime(2026, 8, 20),
      );

      final jsonMap = original.toJson();
      final reconstructed = Hive.fromJson(jsonMap);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.userId, equals('user_beekeeper_123'));
      expect(reconstructed.name, equals(original.name));
      expect(reconstructed.hiveCode, equals(original.hiveCode));
      expect(reconstructed.expectedProductionKg, equals(original.expectedProductionKg));
      expect(reconstructed.currentYearProductionKg, equals(original.currentYearProductionKg));
      expect(reconstructed.feedingRequired, isTrue);
      expect(reconstructed.isHealthy, isFalse);
    });

    test('Two hives have distinct IDs and owner associations', () {
      final now = DateTime(2025, 1, 1);
      final hiveA = Hive(
        id: 'hive-uuid-1',
        userId: 'beekeeper-uuid-A',
        name: 'Hive 1',
        hiveCode: 'H-AAA111',
        apiaryLocation: 'North Hill',
        hiveType: 'Langstroth',
        dateAdded: now,
        queenStatus: 'Mated',
        totalFrames: 10,
        broodFrames: 6,
        colonyStrength: 'Strong',
        queenAgeMonths: 12,
        beeBreed: 'Italian',
        expectedProductionKg: 35.0,
        previousYearProductionKg: 25.0,
        currentYearProductionKg: 28.0,
        honeyType: 'Wildflower',
        lastInspectionDate: now,
        miteStatus: 'Low',
        diseaseStatus: 'None',
        feedingRequired: false,
        queenCondition: 'Excellent',
        overallHealth: 'Healthy',
        notes: '',
        updatedAt: now,
      );

      final hiveB = Hive(
        id: 'hive-uuid-2',
        userId: 'beekeeper-uuid-B',
        name: 'Hive 2',
        hiveCode: 'H-BBB222',
        apiaryLocation: 'South Valley',
        hiveType: 'Langstroth',
        dateAdded: now,
        queenStatus: 'Mated',
        totalFrames: 10,
        broodFrames: 6,
        colonyStrength: 'Strong',
        queenAgeMonths: 12,
        beeBreed: 'Italian',
        expectedProductionKg: 35.0,
        previousYearProductionKg: 25.0,
        currentYearProductionKg: 28.0,
        honeyType: 'Wildflower',
        lastInspectionDate: now,
        miteStatus: 'Low',
        diseaseStatus: 'None',
        feedingRequired: false,
        queenCondition: 'Excellent',
        overallHealth: 'Healthy',
        notes: '',
        updatedAt: now,
      );

      expect(hiveA.id, isNot(equals(hiveB.id)));
      expect(hiveA.hiveCode, isNot(equals(hiveB.hiveCode)));
      expect(hiveA.userId, isNot(equals(hiveB.userId)));
    });
  });
}
