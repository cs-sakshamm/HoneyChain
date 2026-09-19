import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/collector_verification_model.dart';
import '../models/harvester_verification_model.dart';
import '../models/lab_tester_verification_model.dart';
import '../models/packaging_manager_verification_model.dart';
import '../services/verification_api_service.dart';

class VerificationController extends ChangeNotifier {
  final VerificationApiService _apiService;

  HarvesterVerificationModel _verification = HarvesterVerificationModel.initial('default_harvester');
  CollectorVerificationModel _collectorVerification = CollectorVerificationModel.initial('default_collector');
  LabTesterVerificationModel _labVerification = LabTesterVerificationModel.initial('default_lab');
  PackagingManagerVerificationModel _packagingVerification = PackagingManagerVerificationModel.initial('default_packaging');
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Aadhaar OTP State
  bool _aadhaarOtpSent = false;
  int _aadhaarCooldown = 0;
  Timer? _aadhaarCooldownTimer;
  String _pendingAadhaarNumber = '';
  String? _aadhaarTransactionId;
  String? _devAadhaarOtp;



  VerificationController({VerificationApiService? apiService})
      : _apiService = apiService ?? VerificationApiService();

  @override
  void dispose() {
    _aadhaarCooldownTimer?.cancel();
    super.dispose();
  }

  HarvesterVerificationModel get verification => _verification;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Aadhaar OTP Getters
  bool get aadhaarOtpSent => _aadhaarOtpSent;
  int get aadhaarCooldown => _aadhaarCooldown;
  bool get canResendAadhaarOtp => _aadhaarCooldown == 0;
  String get pendingAadhaarNumber => _pendingAadhaarNumber;
  String? get aadhaarTransactionId => _aadhaarTransactionId;
  String? get devAadhaarOtp => _devAadhaarOtp;



  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void resetAadhaarState() {
    _aadhaarOtpSent = false;
    _pendingAadhaarNumber = '';
    _aadhaarTransactionId = null;
    _devAadhaarOtp = null;
    _aadhaarCooldown = 0;
    _aadhaarCooldownTimer?.cancel();
    notifyListeners();
  }



  /// Load verification status for harvester
  Future<void> loadVerification(String harvesterId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.getVerificationStatus(harvesterId);
    } catch (e) {
      _errorMessage = 'Failed to load verification status.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generic verification loader by role
  Future<void> loadVerificationStatus({String? role, String? userId}) async {
    final effectiveId = userId ?? 'default_user';
    final r = (role ?? 'HARVESTER').toUpperCase();
    if (r.contains('COLLECT') || r.contains('PROCESS')) {
      await loadCollectorVerification(effectiveId);
    } else if (r.contains('LAB')) {
      await loadLabVerification(effectiveId);
    } else if (r.contains('PKG') || r.contains('PACKAG')) {
      await loadPackagingVerification(effectiveId);
    } else {
      await loadVerification(effectiveId);
    }
  }

  /// Step 1a: Send Aadhaar OTP
  Future<bool> sendAadhaarOtp(String aadhaarNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final cleanAadhaar = aadhaarNumber.replaceAll(' ', '').trim();
      final res = await _apiService.sendAadhaarOtp(
        harvesterId: _verification.harvesterId,
        aadhaarNumber: cleanAadhaar,
      );
      if (res['success'] == true) {
        _pendingAadhaarNumber = cleanAadhaar;
        _aadhaarTransactionId = res['transactionId'];
        _aadhaarOtpSent = true;
        _aadhaarCooldown = res['cooldownSeconds'] ?? 60;
        _devAadhaarOtp = res['devOtp'];
        _successMessage = res['message'] ?? 'OTP sent to your Aadhaar-linked mobile number.';
        _startAadhaarCooldownTimer();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Failed to send Aadhaar OTP.';
        if (res['cooldownSeconds'] != null && res['cooldownSeconds'] > 0) {
          _aadhaarCooldown = res['cooldownSeconds'];
          _startAadhaarCooldownTimer();
        }
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startAadhaarCooldownTimer() {
    _aadhaarCooldownTimer?.cancel();
    _aadhaarCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_aadhaarCooldown > 0) {
        _aadhaarCooldown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// Step 1b: Verify Aadhaar OTP
  Future<bool> verifyAadhaarOtp(String otp) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.verifyAadhaarOtp(
        harvesterId: _verification.harvesterId,
        aadhaarNumber: _pendingAadhaarNumber,
        transactionId: _aadhaarTransactionId,
        otp: otp,
      );
      _successMessage = 'Aadhaar Verified ✓';
      _aadhaarOtpSent = false;
      _aadhaarTransactionId = null;
      _devAadhaarOtp = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 1 (Fallback / Direct): Submit Government ID
  Future<bool> submitGovernmentId({
    required String docType,
    required String docNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.submitGovernmentId(
        harvesterId: _verification.harvesterId,
        documentType: docType,
        documentNumber: docNumber,
      );
      _successMessage = 'Government ID verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Step 3: Submit Beekeeper Registration ID
  Future<bool> submitRegistrationId({
    required String registrationId,
    String? registrationType,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.submitRegistrationId(
        harvesterId: _verification.harvesterId,
        registrationId: registrationId,
        registrationType: registrationType,
      );
      _successMessage = 'Beekeeper registration ID verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 3.5: Submit FSSAI License
  Future<bool> submitHarvesterFssaiLicense({
    required String fssaiLicense,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.submitHarvesterFssaiLicense(
        harvesterId: _verification.harvesterId,
        fssaiLicense: fssaiLicense,
      );
      _successMessage = 'FSSAI License verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 4: Submit Apiary Location
  Future<bool> submitApiaryLocation({
    required String apiaryName,
    required String apiaryLocation,
    String? apiaryCoordinates,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.submitApiaryLocation(
        harvesterId: _verification.harvesterId,
        apiaryName: apiaryName,
        apiaryLocation: apiaryLocation,
        apiaryCoordinates: apiaryCoordinates,
      );
      _successMessage = 'Apiary location registered and verified.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 5: Final Blockchain Verification Record
  Future<bool> submitBlockchainVerification() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.submitBlockchainVerification(_verification.harvesterId);
      _successMessage = 'Blockchain verification record created and verified on-chain!';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLLECTOR & PROCESSOR PROFILE VERIFICATION (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  CollectorVerificationModel get collectorVerification => _collectorVerification;

  /// Load Collector verification status
  Future<void> loadCollectorVerification(String collectorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _collectorVerification = await _apiService.getCollectorVerificationStatus(collectorId);
    } catch (e) {
      _errorMessage = 'Failed to load collector verification status.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Collector Step 2: Submit Business Verification (Center Name & Center Address)
  Future<bool> submitCollectorBusiness({
    required String collectorId,
    required String organizationName,
    required String facilityLocation,
    String? businessDetails,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _collectorVerification = await _apiService.submitCollectorBusiness(
        collectorId: collectorId,
        organizationName: organizationName,
        facilityLocation: facilityLocation,
        businessDetails: businessDetails,
      );
      _successMessage = 'Business details verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Collector Step 3: Real KYC / ID Verification
  Future<bool> submitCollectorKyc({
    required String collectorId,
    required String governmentIdType,
    required String governmentIdNumber,
    String? licenseNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _collectorVerification = await _apiService.submitCollectorKyc(
        collectorId: collectorId,
        governmentIdType: governmentIdType,
        governmentIdNumber: governmentIdNumber,
        licenseNumber: licenseNumber,
      );
      _successMessage = 'License & KYC verification completed successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAB TESTER PROFILE VERIFICATION (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  LabTesterVerificationModel get labVerification => _labVerification;

  /// Load Lab Tester verification status
  Future<void> loadLabVerification(String labId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _labVerification = await _apiService.getLabVerificationStatus(labId);
    } catch (e) {
      _errorMessage = 'Failed to load lab tester verification status.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Lab Step 2: Submit Laboratory Details
  Future<bool> submitLabDetails({
    required String labId,
    required String labName,
    required String labAddress,
    required String labRegistrationNumber,
    String? accreditation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _labVerification = await _apiService.submitLabDetails(
        labId: labId,
        labName: labName,
        labAddress: labAddress,
        labRegistrationNumber: labRegistrationNumber,
        accreditation: accreditation,
      );
      _successMessage = 'Laboratory details verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lab Step 3: KYC, Qualification & Scope
  Future<bool> submitLabKyc({
    required String labId,
    required String governmentIdType,
    required String governmentIdNumber,
    String? qualification,
    String? authorizedTestingDetails,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _labVerification = await _apiService.submitLabKyc(
        labId: labId,
        governmentIdType: governmentIdType,
        governmentIdNumber: governmentIdNumber,
        qualification: qualification,
        authorizedTestingDetails: authorizedTestingDetails,
      );
      _successMessage = 'License, KYC & Qualification verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PACKAGING MANAGER PROFILE VERIFICATION (3/3 PARAMETERS)
  // ═══════════════════════════════════════════════════════════════════════════

  PackagingManagerVerificationModel get packagingVerification => _packagingVerification;

  /// Load Packaging Manager verification status
  Future<void> loadPackagingVerification(String packagerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _packagingVerification = await _apiService.getPackagingVerificationStatus(packagerId);
    } catch (e) {
      _errorMessage = 'Failed to load packaging verification status.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Packaging Step 2: Submit Packaging Facility Details
  Future<bool> submitPackagingDetails({
    required String packagerId,
    required String organizationName,
    required String facilityLocation,
    required String packagingLicenseNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _packagingVerification = await _apiService.submitPackagingDetails(
        packagerId: packagerId,
        organizationName: organizationName,
        facilityLocation: facilityLocation,
        packagingLicenseNumber: packagingLicenseNumber,
      );
      _successMessage = 'Packaging facility details verified successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Packaging Step 3: Real KYC / ID Verification
  Future<bool> submitPackagingKyc({
    required String packagerId,
    required String governmentIdType,
    required String governmentIdNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _packagingVerification = await _apiService.submitPackagingKyc(
        packagerId: packagerId,
        governmentIdType: governmentIdType,
        governmentIdNumber: governmentIdNumber,
      );
      _successMessage = 'License & KYC verification completed successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

