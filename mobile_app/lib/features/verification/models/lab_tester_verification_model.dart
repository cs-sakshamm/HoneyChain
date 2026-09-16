/// Lab Tester Verification Data Model matching backend schema
/// Enforces the 3 verification parameters (3/3):
/// 1. Identity Verification (Full Name & Mobile OTP)
/// 2. Laboratory Details (Lab Name, Address, Registration Number & Accreditation)
/// 3. License & KYC (Government ID, Qualification & Authorized Scope)
class LabTesterVerificationModel {
  final String id;
  final String labId;

  // 1. Identity Verification
  final String? fullName;
  final String? mobileNumber;
  final String mobileVerified; // Not Started, Pending, Verified
  final DateTime? mobileVerifiedAt;

  // 2. Laboratory Details
  final String? labName;
  final String? labAddress;
  final String? labRegistrationNumber;
  final String? accreditation;
  final String labDetailsVerified; // Not Started, Pending, Verified
  final DateTime? labDetailsVerifiedAt;

  // 3. License, KYC & Qualification
  final String? governmentIdType;
  final String? governmentIdReference;
  final String? governmentIdDocHash;
  final String? qualification;
  final String? authorizedTestingDetails;
  final String? kycProvider;
  final String kycStatus; // Not Started, Pending, Verified, Failed
  final DateTime? kycVerifiedAt;

  // Overall Verification Status (3/3)
  final String verificationStatus; // Not Started, In Progress, Verified
  final DateTime? verifiedAt;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LabTesterVerificationModel({
    required this.id,
    required this.labId,
    this.fullName,
    this.mobileNumber,
    this.mobileVerified = 'Not Started',
    this.mobileVerifiedAt,
    this.labName,
    this.labAddress,
    this.labRegistrationNumber,
    this.accreditation,
    this.labDetailsVerified = 'Not Started',
    this.labDetailsVerifiedAt,
    this.governmentIdType,
    this.governmentIdReference,
    this.governmentIdDocHash,
    this.qualification,
    this.authorizedTestingDetails,
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
  bool get isStep2LabDetailsComplete => labDetailsVerified == 'Verified';
  bool get isStep3KycComplete => kycStatus == 'Verified';

  bool get isFullyVerified =>
      isStep1IdentityComplete && isStep2LabDetailsComplete && isStep3KycComplete && verificationStatus == 'Verified';

  int get completedStepsCount {
    int count = 0;
    if (isStep1IdentityComplete) count++;
    if (isStep2LabDetailsComplete) count++;
    if (isStep3KycComplete) count++;
    return count;
  }

  factory LabTesterVerificationModel.initial(String labId) {
    return LabTesterVerificationModel(
      id: '',
      labId: labId,
    );
  }

  factory LabTesterVerificationModel.fromJson(Map<String, dynamic> json) {
    return LabTesterVerificationModel(
      id: json['id'] as String? ?? '',
      labId: json['labId'] as String? ?? '',
      fullName: json['fullName'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      mobileVerified: json['mobileVerified'] as String? ?? 'Not Started',
      mobileVerifiedAt: json['mobileVerifiedAt'] != null
          ? DateTime.tryParse(json['mobileVerifiedAt'] as String)
          : null,
      labName: json['labName'] as String?,
      labAddress: json['labAddress'] as String?,
      labRegistrationNumber: json['labRegistrationNumber'] as String?,
      accreditation: json['accreditation'] as String?,
      labDetailsVerified: json['labDetailsVerified'] as String? ?? 'Not Started',
      labDetailsVerifiedAt: json['labDetailsVerifiedAt'] != null
          ? DateTime.tryParse(json['labDetailsVerifiedAt'] as String)
          : null,
      governmentIdType: json['governmentIdType'] as String?,
      governmentIdReference: json['governmentIdReference'] as String?,
      governmentIdDocHash: json['governmentIdDocHash'] as String?,
      qualification: json['qualification'] as String?,
      authorizedTestingDetails: json['authorizedTestingDetails'] as String?,
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
      'labId': labId,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'mobileVerified': mobileVerified,
      'mobileVerifiedAt': mobileVerifiedAt?.toIso8601String(),
      'labName': labName,
      'labAddress': labAddress,
      'labRegistrationNumber': labRegistrationNumber,
      'accreditation': accreditation,
      'labDetailsVerified': labDetailsVerified,
      'labDetailsVerifiedAt': labDetailsVerifiedAt?.toIso8601String(),
      'governmentIdType': governmentIdType,
      'governmentIdReference': governmentIdReference,
      'governmentIdDocHash': governmentIdDocHash,
      'qualification': qualification,
      'authorizedTestingDetails': authorizedTestingDetails,
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
