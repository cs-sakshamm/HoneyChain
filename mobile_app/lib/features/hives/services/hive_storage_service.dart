import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hive_model.dart';

/// Storage Service for managing local Hive data persistence
class HiveStorageService {
  static const String _storageKey = 'honeychain_hives_data_v1';

  /// Load hives from SharedPreferences. If empty, populate initial sample data.
  Future<List<Hive>> loadHives() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.trim().isEmpty) {
        final initialHives = _getSampleHives();
        await saveHives(initialHives);
        return initialHives;
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => Hive.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to sample hives on parsing error
      return _getSampleHives();
    }
  }

  /// Save hives list to SharedPreferences
  Future<bool> saveHives(List<Hive> hives) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          hives.map((h) => h.toJson()).toList();
      return await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      return false;
    }
  }

  /// Initial sample hives inspired by real apiary records
  List<Hive> _getSampleHives() {
    final now = DateTime.now();
    return [
      Hive(
        id: 'hive_sample_1',
        name: 'Hive Alpha',
        hiveCode: 'H-001',
        apiaryLocation: 'Main Apiary',
        hiveType: 'Langstroth',
        dateAdded: now.subtract(const Duration(days: 120)),
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
        lastInspectionDate: DateTime(2026, 9, 8),
        miteStatus: 'Low',
        diseaseStatus: 'None',
        feedingRequired: false,
        queenCondition: 'Excellent',
        overallHealth: 'Healthy',
        notes:
            'Strong brood pattern observed across 6 frames. Honey supers filled consistently. Regular inspection logged clean.',
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      Hive(
        id: 'hive_sample_2',
        name: 'Hive Beta',
        hiveCode: 'H-002',
        apiaryLocation: 'North Meadow Apiary',
        hiveType: 'Langstroth',
        dateAdded: now.subtract(const Duration(days: 90)),
        queenStatus: 'Mated',
        totalFrames: 10,
        broodFrames: 4,
        colonyStrength: 'Moderate',
        queenAgeMonths: 18,
        beeBreed: 'Carniolan',
        expectedProductionKg: 30.0,
        previousYearProductionKg: 22.0,
        currentYearProductionKg: 18.0,
        honeyType: 'Clover',
        lastInspectionDate: DateTime(2026, 9, 4),
        miteStatus: 'Medium',
        diseaseStatus: 'None',
        feedingRequired: true,
        queenCondition: 'Good',
        overallHealth: 'Needs Attention',
        notes:
            'Slightly lower brood density. Mite count slightly elevated; organic oxalic acid treatment scheduled.',
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Hive(
        id: 'hive_sample_3',
        name: 'Hive Gamma',
        hiveCode: 'H-003',
        apiaryLocation: 'Riverbank Apiary',
        hiveType: 'Flow Hive',
        dateAdded: now.subtract(const Duration(days: 60)),
        queenStatus: 'Re-queened',
        totalFrames: 8,
        broodFrames: 5,
        colonyStrength: 'Strong',
        queenAgeMonths: 6,
        beeBreed: 'Buckfast',
        expectedProductionKg: 40.0,
        previousYearProductionKg: 32.0,
        currentYearProductionKg: 36.0,
        honeyType: 'Acacia',
        lastInspectionDate: DateTime(2026, 9, 2),
        miteStatus: 'Low',
        diseaseStatus: 'None',
        feedingRequired: false,
        queenCondition: 'Excellent',
        overallHealth: 'Healthy',
        notes:
            'Recently re-queened with pure Buckfast stock. High foraging activity and calm temperament.',
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
