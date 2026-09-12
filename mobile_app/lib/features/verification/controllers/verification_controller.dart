import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/harvester_verification_model.dart';
import '../services/verification_api_service.dart';

class VerificationController extends ChangeNotifier {
  final VerificationApiService _apiService;

  HarvesterVerificationModel _verification = HarvesterVerificationModel.initial('default_harvester');
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // OTP State
  int _otpCooldown = 0;
  Timer? _cooldownTimer;
  String _pendingMobileNumber = '';
  String? _devOtp;

  VerificationController({VerificationApiService? apiService})
      : _apiService = apiService ?? VerificationApiService();

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  HarvesterVerificationModel get verification => _verification;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  int get otpCooldown => _otpCooldown;
  bool get canResendOtp => _otpCooldown == 0;
  String get pendingMobileNumber => _pendingMobileNumber;
  String? get devOtp => _devOtp;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
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

  /// Step 1: Submit Government ID
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

  /// Step 2a: Send Mobile OTP
  Future<bool> sendMobileOtp(String mobile) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.sendMobileOtp(mobile);
      if (res['success'] == true) {
        _pendingMobileNumber = mobile;
        _otpCooldown = res['cooldownSeconds'] ?? 60;
        _devOtp = res['devOtp'];
        _successMessage = res['message'] ?? 'Verification code sent.';
        _startCooldownTimer();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Failed to send verification code.';
        if (res['cooldownSeconds'] != null && res['cooldownSeconds'] > 0) {
          _otpCooldown = res['cooldownSeconds'];
          _startCooldownTimer();
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

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown > 0) {
        _otpCooldown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// Step 2b: Verify Mobile OTP
  Future<bool> verifyMobileOtp(String otp) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _verification = await _apiService.verifyMobileOtp(
        harvesterId: _verification.harvesterId,
        mobile: _pendingMobileNumber,
        otp: otp,
      );
      _successMessage = 'Mobile number verified successfully.';
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
}
