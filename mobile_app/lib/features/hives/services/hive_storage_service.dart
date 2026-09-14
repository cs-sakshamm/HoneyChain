import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../models/hive_model.dart';

/// Service managing Hive data communication with PostgreSQL backend API
/// with graceful local cache fallback.
class HiveStorageService {
  static const String _storageKey = 'honeychain_hives_data_v1';
  final http.Client _client;
  final String _baseUrl;

  HiveStorageService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl();

  static String _resolveBaseUrl() {
    if (kIsWeb) {
      return AppConstants.backendBaseUrl;
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Load hives from PostgreSQL backend API. Fallback to SharedPreferences cache if offline.
  Future<List<Hive>> loadHives() async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
        final hives = jsonList
            .map((item) => Hive.fromJson(item as Map<String, dynamic>))
            .toList();

        // Update local cache
        await saveHives(hives);
        return hives;
      }
    } catch (e) {
      debugPrint('[HiveStorageService] Backend fetch failed: $e. Loading from local cache.');
    }

    // Fallback: load cached hives from SharedPreferences
    return _loadCachedHives();
  }

  /// Create a new Hive in PostgreSQL backend
  Future<bool> createHive(Hive hive) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives');
      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(hive.toJson()))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[HiveStorageService] Backend create failed: $e');
      return false;
    }
  }

  /// Update an existing Hive in PostgreSQL backend
  Future<bool> updateHiveInBackend(Hive hive) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives/${hive.id}');
      final response = await _client
          .put(url, headers: _headers, body: jsonEncode(hive.toJson()))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HiveStorageService] Backend update failed: $e');
      return false;
    }
  }

  /// Delete a Hive in PostgreSQL backend
  Future<bool> deleteHiveFromBackend(String id) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives/$id');
      final response = await _client
          .delete(url, headers: _headers)
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HiveStorageService] Backend delete failed: $e');
      return false;
    }
  }

  /// Generate unique hive code from PostgreSQL backend
  Future<String?> fetchUniqueHiveCode() async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives/code/generate');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] != null) {
          return data['code'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Save hives list to SharedPreferences cache
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

  /// Load cached hives from SharedPreferences
  Future<List<Hive>> _loadCachedHives() async {
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
      return _getSampleHives();
    }
  }

  /// Default baseline hives if cache is uninitialized
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
