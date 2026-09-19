import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';
import 'package:mobile_app/features/verification/models/harvester_verification_model.dart';

void main() {
  group('Harvester Verification Model & Logic Tests', () {
    test('Initial model state is unverified and has 0 completed steps', () {
      final model = HarvesterVerificationModel.initial('harvester-123');

      expect(model.harvesterId, 'harvester-123');
      expect(model.governmentIdVerified, 'Not Started');
      expect(model.mobileVerified, 'Not Started');
      expect(model.registrationVerified, 'Not Started');
      expect(model.locationVerified, 'Not Started');
      expect(model.verificationStatus, 'Not Started');
      expect(model.isStep1Complete, isFalse);
      expect(model.isStep2Complete, isFalse);
      expect(model.isStep3Complete, isFalse);
      expect(model.canSubmitBlockchain, isFalse);
      expect(model.isFullyVerified, isFalse);
      expect(model.completedStepsCount, 0);
    });

    test('Step completion flags and step count calculation', () {
      const step1Model = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-123',
        governmentIdType: 'AADHAAR',
        governmentIdReference: 'AADHAAR-***1234',
        governmentIdVerified: 'Verified',
      );
      expect(step1Model.isStep1Complete, isTrue);
      expect(step1Model.governmentIdReference, 'AADHAAR-***1234');
      expect(step1Model.isStep2Complete, isFalse);
      expect(step1Model.canSubmitBlockchain, isFalse);
      expect(step1Model.completedStepsCount, 1);

      const step2Model = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-123',
        governmentIdVerified: 'Verified',
        registrationId: 'BKR-OR-2026-99',
        registrationVerified: 'Verified',
      );
      expect(step2Model.isStep1Complete, isTrue);
      expect(step2Model.isStep2Complete, isTrue);
      expect(step2Model.completedStepsCount, 2);

      const step3Model = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-123',
        governmentIdVerified: 'Verified',
        registrationVerified: 'Verified',
        apiaryLocation: 'Willamette Valley, OR',
        locationVerified: 'Verified',
      );
      expect(step3Model.completedStepsCount, 3);
      expect(step3Model.canSubmitBlockchain, isTrue);



      const fullyVerifiedModel = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-123',
        governmentIdVerified: 'Verified',
        mobileVerified: 'Verified',
        registrationVerified: 'Verified',
        locationVerified: 'Verified',
        verificationStatus: 'Verified',
        verificationId: 'HV-2026-ABCD1234',
        verificationHash: 'a1b2c3d4e5f6',
        blockchainNetwork: 'HoneyChain Private Ledger',
        transactionHash: '0x1234567890abcdef',
      );
      expect(fullyVerifiedModel.canSubmitBlockchain, isTrue);
      expect(fullyVerifiedModel.isFullyVerified, isTrue);
      expect(fullyVerifiedModel.completedStepsCount, 3);
    });

    test('HarvesterVerificationModel serialization to and from JSON', () {
      final jsonMap = {
        'id': 'ver-uuid-101',
        'harvesterId': 'harv-user-777',
        'governmentIdType': 'Driver License',
        'governmentIdReference': 'DOC-DL-***7890',
        'governmentIdDocHash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'governmentIdVerified': 'Verified',
        'mobileNumber': '+15550189999',
        'mobileVerified': 'Verified',
        'registrationId': 'BKR-OR-8822',
        'registrationType': 'State Registry',
        'registrationVerified': 'Verified',
        'apiaryName': 'Highland Apiary',
        'apiaryLocation': 'Hood River, OR',
        'apiaryCoordinates': '45.7054,-121.5215',
        'locationVerified': 'Verified',
        'verificationStatus': 'Verified',
        'verificationId': 'HV-2026-9A8B7C6D',
        'verificationHash': '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945',
        'blockchainNetwork': 'HoneyChain Private Ledger',
        'transactionHash': '0xabcdef0123456789',
        'blockNumber': 1042,
        'reviewNotes': 'Automated 5-Parameter Verification Gate Approved',
      };

      final parsed = HarvesterVerificationModel.fromJson(jsonMap);
      expect(parsed.id, 'ver-uuid-101');
      expect(parsed.harvesterId, 'harv-user-777');
      expect(parsed.governmentIdType, 'Driver License');
      expect(parsed.governmentIdReference, 'DOC-DL-***7890');
      expect(parsed.isStep1Complete, isTrue);
      expect(parsed.isStep2Complete, isTrue);
      expect(parsed.isStep3Complete, isTrue);
      expect(parsed.canSubmitBlockchain, isTrue);
      expect(parsed.isFullyVerified, isTrue);
      expect(parsed.completedStepsCount, 3);

      final exportedJson = parsed.toJson();
      expect(exportedJson['verificationId'], 'HV-2026-9A8B7C6D');
      expect(exportedJson['verificationStatus'], 'Verified');
      expect(exportedJson['blockNumber'], 1042);
    });

    test('PublicVerificationRecord parsing & status validation', () {
      final publicRecordJson = {
        'found': true,
        'verificationId': 'HV-2026-9A8B7C6D',
        'harvesterName': 'John Apiarist',
        'status': 'Verified',
        'blockchainNetwork': 'HoneyChain Private Ledger',
        'transactionHash': '0xabcdef0123456789',
        'blockNumber': 1042,
        'recordHash': '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945',
        'integrityVerified': true,
        'onChainConfirmed': true,
        'publicDetails': {
          'apiaryName': 'Highland Apiary',
          'generalizedLocation': 'Hood River, OR',
          'registrationType': 'State Registry',
        },
        'verificationUrl': 'https://honeychain.io/verify/harvester/HV-2026-9A8B7C6D',
      };

      final record = PublicVerificationRecord.fromJson(publicRecordJson);
      expect(record.found, isTrue);
      expect(record.verificationId, 'HV-2026-9A8B7C6D');
      expect(record.harvesterName, 'John Apiarist');
      expect(record.integrityVerified, isTrue);
      expect(record.onChainConfirmed, isTrue);
      expect(record.publicDetails?['generalizedLocation'], 'Hood River, OR');
      expect(record.publicDetails?['apiaryCoordinates'], isNull); // Private GPS coordinates never in public record

      final notFoundRecord = PublicVerificationRecord.notFound('Record does not exist');
      expect(notFoundRecord.found, isFalse);
      expect(notFoundRecord.message, 'Record does not exist');
    });
  });

  group('2-Tier Gate Validation (Profile + Harvester Verification)', () {
    test('Incomplete profile fails regardless of verification', () {
      const incompleteProfile = UserProfile(
        name: '',
        email: 'john@honeychain.io',
        phone: '+1 555-0199',
        role: 'HARVESTER',
      );
      expect(incompleteProfile.isProfileComplete, isFalse);
    });

    test('Complete profile with incomplete verification state', () {
      const completeProfile = UserProfile(
        name: 'John Beekeeper',
        email: 'john@honeychain.io',
        phone: '+1 555-0199',
        role: 'HARVESTER',
      );
      expect(completeProfile.isProfileComplete, isTrue);

      final unverifiedHarvester = HarvesterVerificationModel.initial('harvester-1');
      expect(unverifiedHarvester.isFullyVerified, isFalse);

      const partialHarvester = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-1',
        governmentIdVerified: 'Verified',
        mobileVerified: 'Verified',
        registrationVerified: 'Verified',
        locationVerified: 'Not Started',
        verificationStatus: 'Not Started',
      );
      expect(partialHarvester.isFullyVerified, isFalse);
    });

    test('Complete profile with fully verified harvester unlocks gate', () {
      const completeProfile = UserProfile(
        name: 'John Beekeeper',
        email: 'john@honeychain.io',
        phone: '+1 555-0199',
        role: 'HARVESTER',
      );
      const fullyVerified = HarvesterVerificationModel(
        id: 'ver-1',
        harvesterId: 'harvester-1',
        governmentIdVerified: 'Verified',
        mobileVerified: 'Verified',
        registrationVerified: 'Verified',
        locationVerified: 'Verified',
        verificationStatus: 'Verified',
        verificationId: 'HV-2026-12345678',
      );

      expect(completeProfile.isProfileComplete, isTrue);
      expect(fullyVerified.isFullyVerified, isTrue);
    });
  });
}
