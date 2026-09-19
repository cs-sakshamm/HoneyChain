import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/verification/models/lab_tester_verification_model.dart';
import 'package:mobile_app/features/verification/models/packaging_manager_verification_model.dart';

void main() {
  group('Lab Tester Verification Model (2/2) Tests', () {
    test('Initial lab model is unverified with 0 completed steps', () {
      final model = LabTesterVerificationModel.initial('lab-test-1');
      expect(model.labId, 'lab-test-1');
      expect(model.isStep2LabDetailsComplete, isFalse);
      expect(model.isStep3KycComplete, isFalse);
      expect(model.isFullyVerified, isFalse);
      expect(model.completedStepsCount, 0);
    });

    test('2/2 verification progression for Lab Tester', () {
      const step1 = LabTesterVerificationModel(
        id: 'ver-1',
        labId: 'lab-1',
        fullName: 'Dr. Test Chemist',
        mobileNumber: '+919876543210',
        mobileVerified: 'Verified',
      );
      expect(step1.completedStepsCount, 0);
      expect(step1.isFullyVerified, isFalse);

      const step2 = LabTesterVerificationModel(
        id: 'ver-1',
        labId: 'lab-1',
        fullName: 'Dr. Test Chemist',
        mobileVerified: 'Verified',
        labName: 'Apex Food Lab',
        labAddress: 'Sector 62, Food Park',
        labRegistrationNumber: 'NABL-2026-HQ88',
        labDetailsVerified: 'Verified',
      );
      expect(step2.isStep2LabDetailsComplete, isTrue);
      expect(step2.completedStepsCount, 1);
      expect(step2.isFullyVerified, isFalse);

      const step3 = LabTesterVerificationModel(
        id: 'ver-1',
        labId: 'lab-1',
        mobileVerified: 'Verified',
        labDetailsVerified: 'Verified',
        governmentIdType: 'AADHAAR',
        governmentIdReference: 'AADHAAR-***7890',
        qualification: 'M.Sc Analytical Chemistry',
        authorizedTestingDetails: 'Moisture, HMF, Diastase',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
      );
      expect(step3.isStep3KycComplete, isTrue);
      expect(step3.completedStepsCount, 2);
      expect(step3.isFullyVerified, isTrue);
    });

    test('Serialization to and from JSON for Lab Tester', () {
      final original = LabTesterVerificationModel(
        id: 'lab-ver-123',
        labId: 'user-lab-1',
        fullName: 'Dr. Priya Mehta',
        mobileNumber: '+919988776655',
        mobileVerified: 'Verified',
        labName: 'National Quality Labs',
        labAddress: 'Plot 4, Technology Park',
        labRegistrationNumber: 'LAB-REG-999',
        accreditation: 'NABL ISO-17025',
        labDetailsVerified: 'Verified',
        governmentIdType: 'AADHAAR',
        governmentIdReference: 'AADHAAR-***5555',
        qualification: 'Chief Food Analyst',
        authorizedTestingDetails: 'Purity, Sugars, Pollen',
        kycProvider: 'AADHAAR_KYC_GATEWAY',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
      );

      final json = original.toJson();
      final fromJson = LabTesterVerificationModel.fromJson(json);

      expect(fromJson.id, original.id);
      expect(fromJson.labId, original.labId);
      expect(fromJson.labName, 'National Quality Labs');
      expect(fromJson.isFullyVerified, isTrue);
      expect(fromJson.completedStepsCount, 2);
    });
  });

  group('Packaging Manager Verification Model (2/2) Tests', () {
    test('Initial packaging model is unverified with 0 completed steps', () {
      final model = PackagingManagerVerificationModel.initial('pack-test-1');
      expect(model.packagerId, 'pack-test-1');
      expect(model.isStep2FacilityComplete, isFalse);
      expect(model.isStep3KycComplete, isFalse);
      expect(model.isFullyVerified, isFalse);
      expect(model.completedStepsCount, 0);
    });

    test('2/2 verification progression for Packaging Manager', () {
      const step1 = PackagingManagerVerificationModel(
        id: 'pkg-1',
        packagerId: 'pack-1',
        fullName: 'Vikramaditya Singh',
        mobileNumber: '+919123456780',
        mobileVerified: 'Verified',
      );
      expect(step1.completedStepsCount, 0);
      expect(step1.isFullyVerified, isFalse);

      const step2 = PackagingManagerVerificationModel(
        id: 'pkg-1',
        packagerId: 'pack-1',
        mobileVerified: 'Verified',
        organizationName: 'Eco Honey Packers',
        facilityLocation: 'Industrial Estate Block B',
        packagingLicenseNumber: 'PKG-LIC-4422',
        facilityDetailsVerified: 'Verified',
      );
      expect(step2.isStep2FacilityComplete, isTrue);
      expect(step2.completedStepsCount, 1);
      expect(step2.isFullyVerified, isFalse);

      const step3 = PackagingManagerVerificationModel(
        id: 'pkg-1',
        packagerId: 'pack-1',
        mobileVerified: 'Verified',
        facilityDetailsVerified: 'Verified',
        governmentIdType: 'AADHAAR',
        governmentIdReference: 'AADHAAR-***3333',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
      );
      expect(step3.isStep3KycComplete, isTrue);
      expect(step3.completedStepsCount, 2);
      expect(step3.isFullyVerified, isTrue);
    });

    test('Serialization to and from JSON for Packaging Manager', () {
      final original = PackagingManagerVerificationModel(
        id: 'pkg-ver-88',
        packagerId: 'user-pkg-88',
        fullName: 'Aman Verma',
        mobileNumber: '+919876500000',
        mobileVerified: 'Verified',
        organizationName: 'PureHoney Packaging Ltd',
        facilityLocation: 'Cleanroom Unit 5, Agro Park',
        packagingLicenseNumber: 'PKG-FSSAI-888',
        facilityDetailsVerified: 'Verified',
        governmentIdType: 'AADHAAR',
        governmentIdReference: 'AADHAAR-***0000',
        kycProvider: 'AADHAAR_KYC_GATEWAY',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
      );

      final json = original.toJson();
      final fromJson = PackagingManagerVerificationModel.fromJson(json);

      expect(fromJson.id, original.id);
      expect(fromJson.packagerId, original.packagerId);
      expect(fromJson.organizationName, 'PureHoney Packaging Ltd');
      expect(fromJson.isFullyVerified, isTrue);
      expect(fromJson.completedStepsCount, 2);
    });
  });
}
