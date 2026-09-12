/// Harvester Verification Data Model matching backend schema
class HarvesterVerificationModel {
  final String id;
  final String harvesterId;

  // 1. Government ID
  final String? governmentIdType;
  final String? governmentIdReference;
  final String? governmentIdDocHash;
  final String governmentIdVerified; // Not Started, Pending, Verified, Rejected
  final DateTime? governmentIdSubmittedAt;

  // 2. Mobile Number + OTP
  final String? mobileNumber;
  final String mobileVerified; // Not Started, Pending, Verified
  final DateTime? mobileVerifiedAt;

  // 3. Beekeeper Registration ID
  final String? registrationId;
  final String? registrationType;
  final String registrationVerified; // Not Started, Pending, Verified, Rejected
  final DateTime? registrationSubmittedAt;

  // 4. Apiary Location
  final String? apiaryName;
  final String? apiaryLocation;
  final String? apiaryCoordinates;
  final String locationVerified; // Not Started, Pending, Verified
  final DateTime? locationSubmittedAt;

  // 5. Blockchain / Final Verification
  final String verificationStatus; // Not Started, In Progress, Pending Review, Verified, Rejected, Blockchain Pending
  final String? verificationId; // HV-2026-XXXX
  final String? verificationHash;
  final String? blockchainNetwork;
  final String? transactionHash;
  final int? blockNumber;
  final String? reviewNotes;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HarvesterVerificationModel({
    required this.id,
    required this.harvesterId,
    this.governmentIdType,
    this.governmentIdReference,
    this.governmentIdDocHash,
    this.governmentIdVerified = 'Not Started',
    this.governmentIdSubmittedAt,
    this.mobileNumber,
    this.mobileVerified = 'Not Started',
    this.mobileVerifiedAt,
    this.registrationId,
    this.registrationType,
    this.registrationVerified = 'Not Started',
    this.registrationSubmittedAt,
    this.apiaryName,
    this.apiaryLocation,
    this.apiaryCoordinates,
    this.locationVerified = 'Not Started',
    this.locationSubmittedAt,
    this.verificationStatus = 'Not Started',
    this.verificationId,
    this.verificationHash,
    this.blockchainNetwork,
    this.transactionHash,
    this.blockNumber,
    this.reviewNotes,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isStep1Complete => governmentIdVerified == 'Verified';
  bool get isStep2Complete => mobileVerified == 'Verified';
  bool get isStep3Complete => registrationVerified == 'Verified';
  bool get isStep3ManualReview =>
      registrationVerified == 'Manual Verification Required' ||
      registrationVerified == 'Pending Review';
  bool get isStep4Complete => locationVerified == 'Verified';

  String get step3DisplayStatus {
    if (registrationVerified == 'Verified') return 'Registration Verified ✓';
    if (isStep3ManualReview) return 'Manual verification required';
    if (registrationVerified == 'Failed' || registrationVerified == 'Rejected') {
      return 'Registration ID could not be verified';
    }
    if (registrationVerified == 'Pending') return 'Registration verification pending';
    return registrationVerified;
  }

  bool get canSubmitBlockchain =>
      isStep1Complete && isStep2Complete && isStep3Complete && isStep4Complete;

  bool get isFullyVerified =>
      verificationStatus == 'Verified' && verificationId != null;

  int get completedStepsCount {
    int count = 0;
    if (isStep1Complete) count++;
    if (isStep2Complete) count++;
    if (isStep3Complete) count++;
    if (isStep4Complete) count++;
    if (isFullyVerified) count++;
    return count;
  }

  factory HarvesterVerificationModel.initial(String harvesterId) {
    return HarvesterVerificationModel(
      id: '',
      harvesterId: harvesterId,
    );
  }

  factory HarvesterVerificationModel.fromJson(Map<String, dynamic> json) {
    return HarvesterVerificationModel(
      id: json['id'] as String? ?? '',
      harvesterId: json['harvesterId'] as String? ?? '',
      governmentIdType: json['governmentIdType'] as String?,
      governmentIdReference: json['governmentIdReference'] as String?,
      governmentIdDocHash: json['governmentIdDocHash'] as String?,
      governmentIdVerified: json['governmentIdVerified'] as String? ?? 'Not Started',
      governmentIdSubmittedAt: json['governmentIdSubmittedAt'] != null
          ? DateTime.tryParse(json['governmentIdSubmittedAt'] as String)
          : null,
      mobileNumber: json['mobileNumber'] as String?,
      mobileVerified: json['mobileVerified'] as String? ?? 'Not Started',
      mobileVerifiedAt: json['mobileVerifiedAt'] != null
          ? DateTime.tryParse(json['mobileVerifiedAt'] as String)
          : null,
      registrationId: json['registrationId'] as String?,
      registrationType: json['registrationType'] as String?,
      registrationVerified: json['registrationVerified'] as String? ?? 'Not Started',
      registrationSubmittedAt: json['registrationSubmittedAt'] != null
          ? DateTime.tryParse(json['registrationSubmittedAt'] as String)
          : null,
      apiaryName: json['apiaryName'] as String?,
      apiaryLocation: json['apiaryLocation'] as String?,
      apiaryCoordinates: json['apiaryCoordinates'] as String?,
      locationVerified: json['locationVerified'] as String? ?? 'Not Started',
      locationSubmittedAt: json['locationSubmittedAt'] != null
          ? DateTime.tryParse(json['locationSubmittedAt'] as String)
          : null,
      verificationStatus: json['verificationStatus'] as String? ?? 'Not Started',
      verificationId: json['verificationId'] as String?,
      verificationHash: json['verificationHash'] as String?,
      blockchainNetwork: json['blockchainNetwork'] as String?,
      transactionHash: json['transactionHash'] as String?,
      blockNumber: json['blockNumber'] as int?,
      reviewNotes: json['reviewNotes'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'harvesterId': harvesterId,
      'governmentIdType': governmentIdType,
      'governmentIdReference': governmentIdReference,
      'governmentIdDocHash': governmentIdDocHash,
      'governmentIdVerified': governmentIdVerified,
      'governmentIdSubmittedAt': governmentIdSubmittedAt?.toIso8601String(),
      'mobileNumber': mobileNumber,
      'mobileVerified': mobileVerified,
      'mobileVerifiedAt': mobileVerifiedAt?.toIso8601String(),
      'registrationId': registrationId,
      'registrationType': registrationType,
      'registrationVerified': registrationVerified,
      'registrationSubmittedAt': registrationSubmittedAt?.toIso8601String(),
      'apiaryName': apiaryName,
      'apiaryLocation': apiaryLocation,
      'apiaryCoordinates': apiaryCoordinates,
      'locationVerified': locationVerified,
      'locationSubmittedAt': locationSubmittedAt?.toIso8601String(),
      'verificationStatus': verificationStatus,
      'verificationId': verificationId,
      'verificationHash': verificationHash,
      'blockchainNetwork': blockchainNetwork,
      'transactionHash': transactionHash,
      'blockNumber': blockNumber,
      'reviewNotes': reviewNotes,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Model for Public Verification Query Result
class PublicVerificationRecord {
  final bool found;
  final String? verificationId;
  final String? harvesterName;
  final String? status;
  final DateTime? verifiedAt;
  final String? blockchainNetwork;
  final String? transactionHash;
  final int? blockNumber;
  final String? recordHash;
  final bool integrityVerified;
  final bool onChainConfirmed;
  final Map<String, dynamic>? publicDetails;
  final String? verificationUrl;
  final String? message;

  const PublicVerificationRecord({
    required this.found,
    this.verificationId,
    this.harvesterName,
    this.status,
    this.verifiedAt,
    this.blockchainNetwork,
    this.transactionHash,
    this.blockNumber,
    this.recordHash,
    this.integrityVerified = false,
    this.onChainConfirmed = false,
    this.publicDetails,
    this.verificationUrl,
    this.message,
  });

  factory PublicVerificationRecord.notFound([String? message]) {
    return PublicVerificationRecord(
      found: false,
      message: message ?? 'Verification Record Not Found',
    );
  }

  factory PublicVerificationRecord.fromJson(Map<String, dynamic> json) {
    if (json['found'] == false) {
      return PublicVerificationRecord.notFound(json['message'] as String?);
    }

    return PublicVerificationRecord(
      found: true,
      verificationId: json['verificationId'] as String?,
      harvesterName: json['harvesterName'] as String?,
      status: json['status'] as String? ?? 'Verified',
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      blockchainNetwork: json['blockchainNetwork'] as String?,
      transactionHash: json['transactionHash'] as String?,
      blockNumber: json['blockNumber'] as int?,
      recordHash: json['recordHash'] as String?,
      integrityVerified: json['integrityVerified'] as bool? ?? false,
      onChainConfirmed: json['onChainConfirmed'] as bool? ?? false,
      publicDetails: json['publicDetails'] as Map<String, dynamic>?,
      verificationUrl: json['verificationUrl'] as String?,
      message: json['message'] as String?,
    );
  }
}
