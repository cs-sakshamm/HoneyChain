import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../models/hive_model.dart';

/// Service managing Hive data communication with PostgreSQL backend API
/// with genuine database persistence and local cache fallback.
class HiveStorageService {
  static const String _storageKey = 'honeychain_hives_data_v2';
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
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> _headers([String? userId]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (userId != null && userId.trim().isNotEmpty) 'x-user-id': userId.trim(),
      };

  /// Load hives from PostgreSQL backend API for the specified beekeeper.
  Future<List<Hive>> loadHives({String? userId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/hives').replace(
        queryParameters: {
          if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        },
      );
      final response = await _client
          .get(uri, headers: _headers(userId))
          .timeout(const Duration(seconds: 4));

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

    // Fallback: load cached hives from SharedPreferences (empty list if nothing saved)
    return _loadCachedHives();
  }

  /// Create a new Hive in PostgreSQL backend. Returns created Hive with server ID.
  Future<Hive?> createHive(Hive hive, {String? userId}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives');
      final payload = hive.toJson();
      if (userId != null && userId.trim().isNotEmpty) {
        payload['userId'] = userId.trim();
      }

      final response = await _client
          .post(url, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hiveMap = (data['hive'] is Map<String, dynamic>)
            ? data['hive'] as Map<String, dynamic>
            : data;
        return Hive.fromJson(hiveMap);
      } else {
        debugPrint('[HiveStorageService] Backend create rejected: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[HiveStorageService] Backend create failed: $e');
    }
    return null;
  }

  /// Update an existing Hive in PostgreSQL backend
  Future<bool> updateHiveInBackend(Hive hive, {String? userId}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives/${hive.id}');
      final payload = hive.toJson();
      if (userId != null && userId.trim().isNotEmpty) {
        payload['userId'] = userId.trim();
      }

      final response = await _client
          .put(url, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HiveStorageService] Backend update failed: $e');
      return false;
    }
  }

  /// Delete a Hive in PostgreSQL backend
  Future<bool> deleteHiveFromBackend(String id, {String? userId}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/hives/$id');
      final response = await _client
          .delete(url, headers: _headers(userId))
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
      final response = await _client
          .get(url, headers: _headers())
          .timeout(const Duration(seconds: 3));
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

  /// Load cached hives from SharedPreferences (returns [] if none)
  Future<List<Hive>> _loadCachedHives() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.trim().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => Hive.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

