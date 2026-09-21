import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_token_store.dart';
import '../models/hive_model.dart';

/// Service managing Hive data communication with PostgreSQL backend API
/// with genuine database persistence and local cache fallback.
class HiveStorageService {
  static const String _storageKey = 'honeychain_hives_data_v2';

  /// Backend calls include bcrypt-verified JWT round-trips and cloud
  /// PostgreSQL latency (~2s measured locally). Budgets below that aborted
  /// legitimate requests and surfaced them as false "Unable to reach the
  /// backend" errors. 15s matches the auth controller's budget.
  static const Duration _requestTimeout = Duration(seconds: 15);

  final http.Client _client;
  final String _baseUrl;
  String? _lastError;

  String? get lastError => _lastError;

  HiveStorageService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl();

  static String _resolveBaseUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> _headers([String? userId]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthTokenStore.authHeader(),
      };

  /// Load hives from PostgreSQL backend API for the specified beekeeper.
  Future<List<Hive>> loadHives({String? userId}) async {
    http.Response? response;
    try {
      _lastError = null;
      final uri = Uri.parse('$_baseUrl/api/hives').replace(
        queryParameters: {
          if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        },
      );
      response = await _client
          .get(uri, headers: _headers(userId))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
        final hives = jsonList
            .map((item) => Hive.fromJson(item as Map<String, dynamic>))
            .toList();

        // Update local cache
        await saveHives(hives);
        return hives;
      }

      // Real API rejection (401 expired token, 403 role, 422 schema, 5xx…):
      // surface the backend's own message instead of masking it as a
      // connection failure — the bug this service used to have.
      _lastError = _extractErrorMessage(response.body) ??
          'Backend rejected the hive list request (HTTP ${response.statusCode}).';
      debugPrint('[HiveStorageService] Backend list rejected: ${response.statusCode} - ${response.body}');
    } catch (e) {
      _lastError = 'Unable to reach the backend. Please verify the API server is running.';
      debugPrint('[HiveStorageService] Backend fetch failed: $e. Loading from local cache.');
    }

    // Fallback: load cached hives from SharedPreferences (empty list if nothing saved)
    return _loadCachedHives();
  }

  /// Create a new Hive in PostgreSQL backend. Returns created Hive with server ID.
  Future<Hive?> createHive(Hive hive, {String? userId}) async {
    try {
      _lastError = null;
      final url = Uri.parse('$_baseUrl/api/hives');
      final payload = hive.toJson();
      if (userId != null && userId.trim().isNotEmpty) {
        payload['userId'] = userId.trim();
      }

      final response = await _client
          .post(url, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(_requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hiveMap = (data['hive'] is Map<String, dynamic>)
            ? data['hive'] as Map<String, dynamic>
            : data;
        return Hive.fromJson(hiveMap);
      } else {
        _lastError = _extractErrorMessage(response.body) ??
            'Failed to save hive data. Please try again.';
        debugPrint('[HiveStorageService] Backend create rejected: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _lastError = 'Unable to reach the backend. Please verify the API server is running.';
      debugPrint('[HiveStorageService] Backend create failed: $e');
    }
    return null;
  }

  /// Update an existing Hive in PostgreSQL backend
  Future<bool> updateHiveInBackend(Hive hive, {String? userId}) async {
    try {
      _lastError = null;
      final url = Uri.parse('$_baseUrl/api/hives/${hive.id}');
      final payload = hive.toJson();
      if (userId != null && userId.trim().isNotEmpty) {
        payload['userId'] = userId.trim();
      }

      final response = await _client
          .put(url, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) return true;
      _lastError = _extractErrorMessage(response.body) ??
          'Failed to update hive data. Please try again.';
      debugPrint('[HiveStorageService] Backend update rejected: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _lastError = 'Unable to reach the backend. Please verify the API server is running.';
      debugPrint('[HiveStorageService] Backend update failed: $e');
      return false;
    }
  }

  /// Delete a Hive in PostgreSQL backend
  Future<bool> deleteHiveFromBackend(String id, {String? userId}) async {
    try {
      _lastError = null;
      final url = Uri.parse('$_baseUrl/api/hives/$id');
      final response = await _client
          .delete(url, headers: _headers(userId))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) return true;
      _lastError = _extractErrorMessage(response.body) ??
          'Failed to delete hive data. Please try again.';
      return false;
    } catch (e) {
      _lastError = 'Unable to reach the backend. Please verify the API server is running.';
      debugPrint('[HiveStorageService] Backend delete failed: $e');
      return false;
    }
  }

  /// Generate unique hive code from PostgreSQL backend
  Future<String?> fetchUniqueHiveCode() async {
    try {
      _lastError = null;
      final url = Uri.parse('$_baseUrl/api/hives/code/generate');
      final response = await _client
          .get(url, headers: _headers())
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] != null) {
          return data['code'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is Map<String, dynamic>) {
          final message = detail['message'] ?? detail['error'];
          if (message is String && message.trim().isNotEmpty) return message;
        }
        final message = data['message'] ?? data['error'];
        if (message is String && message.trim().isNotEmpty) return message;
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

