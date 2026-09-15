/// Collector Verification Data Model matching backend schema
/// Enforces the 3 verification parameters:
/// 1. Identity Verification (Full Name & Mobile OTP)
/// 2. Business Verification (Center Name & Center Address)
/// 3. License & KYC (Government ID & Legitimate KYC Verification)
class CollectorVerificationModel {
  final String id;
  final String collectorId;

  // 1. Identity Verification
  final String? fullName;
  final String? mobileNumber;
  final String mobileVerified; // Not Started, Pending, Verified
  final DateTime? mobileVerifiedAt;

  // 2. Business Verification
  final String? organizationName;
  final String? facilityLocation;
  final String? businessDetails;
  final String businessVerified; // Not Started, Pending, Verified
  final DateTime? businessVerifiedAt;

  // 3. License & KYC
  final String? governmentIdType;
  final String? governmentIdReference;
  final String? governmentIdDocHash;
  final String? licenseNumber;
  final String? kycProvider;
  final String kycStatus; // Not Started, Pending, Verified, Failed
  final DateTime? kycVerifiedAt;

  // Overall Verification Status (3/3)
  final String verificationStatus; // Not Started, In Progress, Verified
  final DateTime? verifiedAt;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CollectorVerificationModel({
    required this.id,
    required this.collectorId,
    this.fullName,
    this.mobileNumber,
    this.mobileVerified = 'Not Started',
    this.mobileVerifiedAt,
    this.organizationName,
    this.facilityLocation,
    this.businessDetails,
    this.businessVerified = 'Not Started',
    this.businessVerifiedAt,
    this.governmentIdType,
    this.governmentIdReference,
    this.governmentIdDocHash,
    this.licenseNumber,
    this.kycProvider,
    this.kycStatus = 'Not Started',
    this.kycVerifiedAt,
    this.verificationStatus = 'Not Started',
    this.verifiedAt,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isStep1IdentityComplete => mobileVerified == 'Verified';
  bool get isStep2BusinessComplete => businessVerified == 'Verified';
  bool get isStep3KycComplete => kycStatus == 'Verified';

  bool get isFullyVerified =>
      isStep1IdentityComplete && isStep2BusinessComplete && isStep3KycComplete;

  int get completedStepsCount {
    int count = 0;
    if (isStep1IdentityComplete) count++;
    if (isStep2BusinessComplete) count++;
    if (isStep3KycComplete) count++;
    return count;
  }

  factory CollectorVerificationModel.initial(String collectorId) {
    return CollectorVerificationModel(
      id: '',
      collectorId: collectorId,
    );
  }

  factory CollectorVerificationModel.fromJson(Map<String, dynamic> json) {
    return CollectorVerificationModel(
      id: json['id'] as String? ?? '',
      collectorId: json['collectorId'] as String? ?? '',
      fullName: json['fullName'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      mobileVerified: json['mobileVerified'] as String? ?? 'Not Started',
      mobileVerifiedAt: json['mobileVerifiedAt'] != null
          ? DateTime.tryParse(json['mobileVerifiedAt'] as String)
          : null,
      organizationName: json['organizationName'] as String?,
      facilityLocation: json['facilityLocation'] as String?,
      businessDetails: json['businessDetails'] as String?,
      businessVerified: json['businessVerified'] as String? ?? 'Not Started',
      businessVerifiedAt: json['businessVerifiedAt'] != null
          ? DateTime.tryParse(json['businessVerifiedAt'] as String)
          : null,
      governmentIdType: json['governmentIdType'] as String?,
      governmentIdReference: json['governmentIdReference'] as String?,
      governmentIdDocHash: json['governmentIdDocHash'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      kycProvider: json['kycProvider'] as String?,
      kycStatus: json['kycStatus'] as String? ?? 'Not Started',
      kycVerifiedAt: json['kycVerifiedAt'] != null
          ? DateTime.tryParse(json['kycVerifiedAt'] as String)
          : null,
      verificationStatus: json['verificationStatus'] as String? ?? 'Not Started',
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      reviewNotes: json['reviewNotes'] as String?,
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
      'collectorId': collectorId,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'mobileVerified': mobileVerified,
      'mobileVerifiedAt': mobileVerifiedAt?.toIso8601String(),
      'organizationName': organizationName,
      'facilityLocation': facilityLocation,
      'businessDetails': businessDetails,
      'businessVerified': businessVerified,
      'businessVerifiedAt': businessVerifiedAt?.toIso8601String(),
      'governmentIdType': governmentIdType,
      'governmentIdReference': governmentIdReference,
      'governmentIdDocHash': governmentIdDocHash,
      'licenseNumber': licenseNumber,
      'kycProvider': kycProvider,
      'kycStatus': kycStatus,
      'kycVerifiedAt': kycVerifiedAt?.toIso8601String(),
      'verificationStatus': verificationStatus,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
