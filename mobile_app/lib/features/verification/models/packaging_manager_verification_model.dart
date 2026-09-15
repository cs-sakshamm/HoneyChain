/// Packaging Manager Verification Data Model matching backend schema
/// Enforces the 3 verification parameters (3/3):
/// 1. Identity Verification (Full Name & Mobile OTP)
/// 2. Facility Details (Facility/Company Name & Plant Address)
/// 3. License & KYC (Government ID & Packaging License)
class PackagingManagerVerificationModel {
  final String id;
  final String packagerId;

  // 1. Identity Verification
  final String? fullName;
  final String? mobileNumber;
  final String mobileVerified; // Not Started, Pending, Verified
  final DateTime? mobileVerifiedAt;

  // 2. Packaging Facility Details
  final String? organizationName;
  final String? facilityLocation;
  final String? packagingLicenseNumber;
  final String facilityDetailsVerified; // Not Started, Pending, Verified
  final DateTime? facilityDetailsVerifiedAt;

  // 3. License & KYC
  final String? governmentIdType;
  final String? governmentIdReference;
  final String? governmentIdDocHash;
  final String? kycProvider;
  final String kycStatus; // Not Started, Pending, Verified, Failed
  final DateTime? kycVerifiedAt;

  // Overall Verification Status (3/3)
  final String verificationStatus; // Not Started, In Progress, Verified
  final DateTime? verifiedAt;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PackagingManagerVerificationModel({
    required this.id,
    required this.packagerId,
    this.fullName,
    this.mobileNumber,
    this.mobileVerified = 'Not Started',
    this.mobileVerifiedAt,
    this.organizationName,
    this.facilityLocation,
    this.packagingLicenseNumber,
    this.facilityDetailsVerified = 'Not Started',
    this.facilityDetailsVerifiedAt,
    this.governmentIdType,
    this.governmentIdReference,
    this.governmentIdDocHash,
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
  bool get isStep2FacilityComplete => facilityDetailsVerified == 'Verified';
  bool get isStep3KycComplete => kycStatus == 'Verified';

  bool get isFullyVerified =>
      isStep1IdentityComplete && isStep2FacilityComplete && isStep3KycComplete && verificationStatus == 'Verified';

  int get completedStepsCount {
    int count = 0;
    if (isStep1IdentityComplete) count++;
    if (isStep2FacilityComplete) count++;
    if (isStep3KycComplete) count++;
    return count;
  }

  factory PackagingManagerVerificationModel.initial(String packagerId) {
    return PackagingManagerVerificationModel(
      id: '',
      packagerId: packagerId,
    );
  }

  factory PackagingManagerVerificationModel.fromJson(Map<String, dynamic> json) {
    return PackagingManagerVerificationModel(
      id: json['id'] as String? ?? '',
      packagerId: json['packagerId'] as String? ?? '',
      fullName: json['fullName'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      mobileVerified: json['mobileVerified'] as String? ?? 'Not Started',
      mobileVerifiedAt: json['mobileVerifiedAt'] != null
          ? DateTime.tryParse(json['mobileVerifiedAt'] as String)
          : null,
      organizationName: json['organizationName'] as String?,
      facilityLocation: json['facilityLocation'] as String?,
      packagingLicenseNumber: json['packagingLicenseNumber'] as String?,
      facilityDetailsVerified: json['facilityDetailsVerified'] as String? ?? 'Not Started',
      facilityDetailsVerifiedAt: json['facilityDetailsVerifiedAt'] != null
          ? DateTime.tryParse(json['facilityDetailsVerifiedAt'] as String)
          : null,
      governmentIdType: json['governmentIdType'] as String?,
      governmentIdReference: json['governmentIdReference'] as String?,
      governmentIdDocHash: json['governmentIdDocHash'] as String?,
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
      'packagerId': packagerId,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'mobileVerified': mobileVerified,
      'mobileVerifiedAt': mobileVerifiedAt?.toIso8601String(),
      'organizationName': organizationName,
      'facilityLocation': facilityLocation,
      'packagingLicenseNumber': packagingLicenseNumber,
      'facilityDetailsVerified': facilityDetailsVerified,
      'facilityDetailsVerifiedAt': facilityDetailsVerifiedAt?.toIso8601String(),
      'governmentIdType': governmentIdType,
      'governmentIdReference': governmentIdReference,
      'governmentIdDocHash': governmentIdDocHash,
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
