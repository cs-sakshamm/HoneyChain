import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/harvester_verification_model.dart';

class VerificationApiService {
  static String get _defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  final String baseUrl;
  final http.Client _client;

  VerificationApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Fetch verification status for a harvester
  Future<HarvesterVerificationModel> getVerificationStatus(String harvesterId) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/status/$cleanId');
    try {
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['verification'] != null) {
          final model = HarvesterVerificationModel.fromJson(data['verification']);
          await _cacheLocalVerification(cleanId, model);
          return model;
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? data['message'] ?? 'Failed to load verification status.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[VerificationApi] Network query failed: $e, checking cached record.');
      final cached = await _loadCachedVerification(cleanId);
      return cached;
    }

    return _loadCachedVerification(cleanId);
  }

  /// Step 1a: Send Aadhaar OTP to linked mobile
  Future<Map<String, dynamic>> sendAadhaarOtp({
    required String harvesterId,
    required String aadhaarNumber,
  }) async {
    final cleanId = harvesterId.trim();
    final cleanAadhaar = aadhaarNumber.replaceAll(' ', '').trim();
    final url = Uri.parse('$baseUrl/verification/harvester/aadhaar/send-otp');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'aadhaarNumber': cleanAadhaar,
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 429) {
      return data;
    }
    return {'success': false, 'message': data['error'] ?? data['message'] ?? 'Failed to send Aadhaar OTP.'};
  }

  /// Step 1b: Verify Aadhaar OTP
  Future<HarvesterVerificationModel> verifyAadhaarOtp({
    required String harvesterId,
    required String aadhaarNumber,
    required String otp,
    String? transactionId,
  }) async {
    final cleanId = harvesterId.trim();
    final cleanAadhaar = aadhaarNumber.replaceAll(' ', '').trim();
    final url = Uri.parse('$baseUrl/verification/harvester/aadhaar/verify-otp');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'aadhaarNumber': cleanAadhaar,
      'otp': otp.trim(),
      if (transactionId != null && transactionId.isNotEmpty) 'transactionId': transactionId,
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to verify Aadhaar OTP.');
    }
  }

  /// Step 1: Submit Government ID (Standard Fallback)
  Future<HarvesterVerificationModel> submitGovernmentId({
    required String harvesterId,
    required String documentType,
    required String documentNumber,
  }) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/government-id');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'documentType': documentType.trim(),
      'documentNumber': documentNumber.replaceAll(' ', '').trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to verify Government ID.');
    }
  }

  /// Step 2a: Send OTP to Mobile Number
  Future<Map<String, dynamic>> sendMobileOtp(String mobile) async {
    final url = Uri.parse('$baseUrl/verification/harvester/mobile/send-otp');
    final body = jsonEncode({'mobile': mobile.trim()});

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 429) {
      return data;
    }
    return {'success': false, 'message': data['error'] ?? data['message'] ?? 'Failed to send OTP.'};
  }

  /// Step 2b: Verify Mobile OTP
  Future<HarvesterVerificationModel> verifyMobileOtp({
    required String harvesterId,
    required String mobile,
    required String otp,
  }) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/mobile/verify-otp');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'mobile': mobile.trim(),
      'otp': otp.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Invalid verification code.');
    }
  }

  /// Step 3: Submit Beekeeper Registration ID
  Future<HarvesterVerificationModel> submitRegistrationId({
    required String harvesterId,
    required String registrationId,
    String? registrationType,
  }) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/registration');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'registrationId': registrationId.trim(),
      'registrationType': (registrationType ?? 'STATE_REGISTRY').trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to verify Beekeeper Registration ID.');
    }
  }

  /// Step 4: Submit Apiary Location
  Future<HarvesterVerificationModel> submitApiaryLocation({
    required String harvesterId,
    required String apiaryName,
    required String apiaryLocation,
    String? apiaryCoordinates,
  }) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/location');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'apiaryName': apiaryName.trim(),
      'apiaryLocation': apiaryLocation.trim(),
      'apiaryCoordinates': apiaryCoordinates?.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to verify Apiary Location.');
    }
  }

  /// Step 5: Submit Final Blockchain Verification
  Future<HarvesterVerificationModel> submitBlockchainVerification(String harvesterId) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/blockchain-verify');
    final body = jsonEncode({'harvesterId': cleanId});

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to commit verification on blockchain.');
    }
  }

  /// Public Verification Query by Verification ID
  Future<PublicVerificationRecord> queryPublicVerification(String verificationId) async {
    final cleanId = verificationId.trim().toUpperCase();
    final url = Uri.parse('$baseUrl/verify/harvester/$cleanId');

    try {
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 6));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return PublicVerificationRecord.fromJson(data);
      }
      return PublicVerificationRecord.notFound(data['message'] ?? 'Verification Record Not Found');
    } catch (e) {
      return PublicVerificationRecord.notFound('Could not verify record on ledger. Network connection error.');
    }
  }

  // Local storage caching helpers
  Future<void> _cacheLocalVerification(String harvesterId, HarvesterVerificationModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(model.toJson());
      await prefs.setString('cached_harvester_ver_$harvesterId', jsonStr);
      if (model.verificationId != null) {
        await prefs.setString('cached_ver_${model.verificationId}', jsonStr);
      }
    } catch (_) {}
  }

  Future<HarvesterVerificationModel> _loadCachedVerification(String harvesterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_harvester_ver_$harvesterId');
      if (raw != null) {
        return HarvesterVerificationModel.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    return HarvesterVerificationModel.initial(harvesterId);
  }
}

