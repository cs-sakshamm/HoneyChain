import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_token_store.dart';
import '../models/collector_verification_model.dart';
import '../models/harvester_verification_model.dart';
import '../models/lab_tester_verification_model.dart';
import '../models/packaging_manager_verification_model.dart';

class VerificationApiService {
  static String get _defaultBaseUrl {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return '${AppConstants.backendBaseUrl}/api';
  }

  final String baseUrl;
  final http.Client _client;

  VerificationApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthTokenStore.authHeader(),
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

  /// Step 3.5: Submit FSSAI License
  Future<HarvesterVerificationModel> submitHarvesterFssaiLicense({
    required String harvesterId,
    required String fssaiLicense,
  }) async {
    final cleanId = harvesterId.trim();
    final url = Uri.parse('$baseUrl/verification/harvester/fssai');
    final body = jsonEncode({
      'harvesterId': cleanId,
      'fssaiLicense': fssaiLicense.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = HarvesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to verify FSSAI License.');
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

  // ═══════════════════════════════════════════════════════════════════════════
  // COLLECTOR & PROCESSING VERIFICATION ENDPOINTS (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch verification status for a Collector / Processor
  Future<CollectorVerificationModel> getCollectorVerificationStatus(String collectorId) async {
    final cleanId = collectorId.trim();
    final url = Uri.parse('$baseUrl/verification/collector/status/$cleanId');
    try {
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['verification'] != null) {
          final model = CollectorVerificationModel.fromJson(data['verification']);
          await _cacheLocalCollectorVerification(cleanId, model);
          return model;
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? data['message'] ?? 'Failed to load collector verification.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[VerificationApi] Collector verification query failed: $e, loading cached record.');
      return _loadCachedCollectorVerification(cleanId);
    }

    return _loadCachedCollectorVerification(cleanId);
  }



  /// Collector Step 2: Submit Business Verification (Center Name & Center Address)
  Future<CollectorVerificationModel> submitCollectorBusiness({
    required String collectorId,
    required String organizationName,
    required String facilityLocation,
    String? businessDetails,
  }) async {
    final cleanId = collectorId.trim();
    final url = Uri.parse('$baseUrl/verification/collector/business');
    final body = jsonEncode({
      'collectorId': cleanId,
      'organizationName': organizationName.trim(),
      'facilityLocation': facilityLocation.trim(),
      if (businessDetails != null) 'businessDetails': businessDetails.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = CollectorVerificationModel.fromJson(data['verification']);
      await _cacheLocalCollectorVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to submit business details.');
    }
  }

  /// Collector Step 3: Real KYC / ID Verification
  Future<CollectorVerificationModel> submitCollectorKyc({
    required String collectorId,
    required String governmentIdType,
    required String governmentIdNumber,
    String? licenseNumber,
  }) async {
    final cleanId = collectorId.trim();
    final url = Uri.parse('$baseUrl/verification/collector/kyc');
    final body = jsonEncode({
      'collectorId': cleanId,
      'governmentIdType': governmentIdType.trim(),
      'governmentIdNumber': governmentIdNumber.replaceAll(' ', '').trim(),
      if (licenseNumber != null) 'licenseNumber': licenseNumber.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = CollectorVerificationModel.fromJson(data['verification']);
      await _cacheLocalCollectorVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'KYC verification failed.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAB TESTER VERIFICATION ENDPOINTS (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch verification status for a Lab Tester
  Future<LabTesterVerificationModel> getLabVerificationStatus(String labId) async {
    final cleanId = labId.trim();
    final url = Uri.parse('$baseUrl/verification/lab/status/$cleanId');
    try {
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['verification'] != null) {
          final model = LabTesterVerificationModel.fromJson(data['verification']);
          await _cacheLocalLabVerification(cleanId, model);
          return model;
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? data['message'] ?? 'Failed to load lab verification.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[VerificationApi] Lab verification query failed: $e, loading cached record.');
      return _loadCachedLabVerification(cleanId);
    }

    return _loadCachedLabVerification(cleanId);
  }



  /// Lab Step 2: Submit Laboratory Details
  Future<LabTesterVerificationModel> submitLabDetails({
    required String labId,
    required String labName,
    required String labAddress,
    required String labRegistrationNumber,
    String? accreditation,
  }) async {
    final cleanId = labId.trim();
    final url = Uri.parse('$baseUrl/verification/lab/details');
    final body = jsonEncode({
      'labId': cleanId,
      'labName': labName.trim(),
      'labAddress': labAddress.trim(),
      'labRegistrationNumber': labRegistrationNumber.trim(),
      if (accreditation != null) 'accreditation': accreditation.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = LabTesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalLabVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to submit lab details.');
    }
  }

  /// Lab Step 3: KYC, Qualification & Scope
  Future<LabTesterVerificationModel> submitLabKyc({
    required String labId,
    required String governmentIdType,
    required String governmentIdNumber,
    String? qualification,
    String? authorizedTestingDetails,
  }) async {
    final cleanId = labId.trim();
    final url = Uri.parse('$baseUrl/verification/lab/kyc');
    final body = jsonEncode({
      'labId': cleanId,
      'governmentIdType': governmentIdType.trim(),
      'governmentIdNumber': governmentIdNumber.replaceAll(' ', '').trim(),
      if (qualification != null) 'qualification': qualification.trim(),
      if (authorizedTestingDetails != null) 'authorizedTestingDetails': authorizedTestingDetails.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = LabTesterVerificationModel.fromJson(data['verification']);
      await _cacheLocalLabVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'KYC verification failed.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PACKAGING MANAGER VERIFICATION ENDPOINTS (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch verification status for a Packaging Manager
  Future<PackagingManagerVerificationModel> getPackagingVerificationStatus(String packagerId) async {
    final cleanId = packagerId.trim();
    final url = Uri.parse('$baseUrl/verification/packaging/status/$cleanId');
    try {
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['verification'] != null) {
          final model = PackagingManagerVerificationModel.fromJson(data['verification']);
          await _cacheLocalPackagingVerification(cleanId, model);
          return model;
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? data['message'] ?? 'Failed to load packaging verification.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[VerificationApi] Packaging verification query failed: $e, loading cached record.');
      return _loadCachedPackagingVerification(cleanId);
    }

    return _loadCachedPackagingVerification(cleanId);
  }



  /// Packaging Step 2: Submit Packaging Facility Details
  Future<PackagingManagerVerificationModel> submitPackagingDetails({
    required String packagerId,
    required String organizationName,
    required String facilityLocation,
    required String packagingLicenseNumber,
  }) async {
    final cleanId = packagerId.trim();
    final url = Uri.parse('$baseUrl/verification/packaging/details');
    final body = jsonEncode({
      'packagerId': cleanId,
      'organizationName': organizationName.trim(),
      'facilityLocation': facilityLocation.trim(),
      'packagingLicenseNumber': packagingLicenseNumber.trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = PackagingManagerVerificationModel.fromJson(data['verification']);
      await _cacheLocalPackagingVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Failed to submit facility details.');
    }
  }

  /// Packaging Step 3: Real KYC / ID Verification
  Future<PackagingManagerVerificationModel> submitPackagingKyc({
    required String packagerId,
    required String governmentIdType,
    required String governmentIdNumber,
  }) async {
    final cleanId = packagerId.trim();
    final url = Uri.parse('$baseUrl/verification/packaging/kyc');
    final body = jsonEncode({
      'packagerId': cleanId,
      'governmentIdType': governmentIdType.trim(),
      'governmentIdNumber': governmentIdNumber.replaceAll(' ', '').trim(),
    });

    final response = await _client.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true && data['verification'] != null) {
      final model = PackagingManagerVerificationModel.fromJson(data['verification']);
      await _cacheLocalPackagingVerification(cleanId, model);
      return model;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'KYC verification failed.');
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

  Future<void> _cacheLocalCollectorVerification(String collectorId, CollectorVerificationModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(model.toJson());
      await prefs.setString('cached_collector_ver_$collectorId', jsonStr);
    } catch (_) {}
  }

  Future<CollectorVerificationModel> _loadCachedCollectorVerification(String collectorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_collector_ver_$collectorId');
      if (raw != null) {
        return CollectorVerificationModel.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    return CollectorVerificationModel.initial(collectorId);
  }

  Future<void> _cacheLocalLabVerification(String labId, LabTesterVerificationModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(model.toJson());
      await prefs.setString('cached_lab_ver_$labId', jsonStr);
    } catch (_) {}
  }

  Future<LabTesterVerificationModel> _loadCachedLabVerification(String labId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_lab_ver_$labId');
      if (raw != null) {
        return LabTesterVerificationModel.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    return LabTesterVerificationModel.initial(labId);
  }

  Future<void> _cacheLocalPackagingVerification(String packagerId, PackagingManagerVerificationModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(model.toJson());
      await prefs.setString('cached_packaging_ver_$packagerId', jsonStr);
    } catch (_) {}
  }

  Future<PackagingManagerVerificationModel> _loadCachedPackagingVerification(String packagerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_packaging_ver_$packagerId');
      if (raw != null) {
        return PackagingManagerVerificationModel.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    return PackagingManagerVerificationModel.initial(packagerId);
  }
}


