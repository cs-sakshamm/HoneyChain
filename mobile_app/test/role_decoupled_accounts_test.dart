import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/authentication/auth_controller.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';

void main() {
  group('Role-Decoupled Multi-Account Protocol Tests', () {
    test('Converts between UserRole enum and canonical string representation accurately', () {
      expect(userRoleToString(UserRole.harvester), 'HARVESTER');
      expect(userRoleToString(UserRole.collectionProcessing), 'COLLECTOR_PROCESSOR');
      expect(userRoleToString(UserRole.labTesting), 'LAB');
      expect(userRoleToString(UserRole.packaging), 'PACKAGING');

      expect(userRoleFromString('HARVESTER'), UserRole.harvester);
      expect(userRoleFromString('COLLECTOR_PROCESSOR'), UserRole.collectionProcessing);
      expect(userRoleFromString('COLLECTION'), UserRole.collectionProcessing);
      expect(userRoleFromString('LAB'), UserRole.labTesting);
      expect(userRoleFromString('LAB_TESTING'), UserRole.labTesting);
      expect(userRoleFromString('PACKAGING'), UserRole.packaging);
      expect(userRoleFromString('PACKAGER'), UserRole.packaging);
    });

    test('Harvester profile completion requires name and email (phone optional)', () {
      // A Harvester without a name is incomplete.
      const noName = UserProfile(
        name: '',
        email: 'maria@honeychain.io',
        phone: '',
        role: 'HARVESTER',
      );
      expect(noName.isProfileComplete, false);

      // A Harvester without an email is incomplete.
      const noEmail = UserProfile(
        name: 'Maria Harvester',
        email: '',
        phone: '',
        role: 'HARVESTER',
      );
      expect(noEmail.isProfileComplete, false);

      // A Google OAuth Harvester with no phone but valid name+email IS complete.
      const googleHarv = UserProfile(
        name: 'Maria Harvester',
        email: 'maria@honeychain.io',
        phone: '',
        role: 'HARVESTER',
      );
      expect(googleHarv.isProfileComplete, true);

      // A Harvester with name, email, and phone is also complete.
      const completeHarv = UserProfile(
        name: 'Maria Harvester',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'HARVESTER',
        beekeeperId: 'HC-BK-991283',
      );
      expect(completeHarv.isProfileComplete, true);
    });

    test('Collection & Processing profile completion requires facility details and license', () {
      const incompleteCol = UserProfile(
        name: 'Cascade Processing Manager',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'COLLECTOR_PROCESSOR',
      );
      expect(incompleteCol.isProfileComplete, false);

      const completeCol = UserProfile(
        name: 'Cascade Processing Manager',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'COLLECTOR_PROCESSOR',
        organizationName: 'Cascade Honey Processing Ltd.',
        facilityLocation: 'Bend Logistics Hub, OR',
        licenseNumber: 'FSSAI-PROC-2026-9812',
      );
      expect(completeCol.isProfileComplete, true);
    });

    test('Lab Tester profile completion requires lab name, address, and accreditation', () {
      const incompleteLab = UserProfile(
        name: 'Dr. Evelyn Vance',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'LAB',
      );
      expect(incompleteLab.isProfileComplete, false);

      const completeLab = UserProfile(
        name: 'Dr. Evelyn Vance',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'LAB',
        organizationName: 'Pacific Pure Apiculture Testing Labs',
        facilityLocation: 'Corvallis Bio-Tech Campus, OR',
        licenseNumber: 'NABL-ISO-17025-2026',
        designation: 'Senior Analytical Chemist',
      );
      expect(completeLab.isProfileComplete, true);
    });

    test('Packaging Manager profile completion requires company, location, and license', () {
      const incompletePkg = UserProfile(
        name: 'Marcus Sterling',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'PACKAGING',
      );
      expect(incompletePkg.isProfileComplete, false);

      const completePkg = UserProfile(
        name: 'Marcus Sterling',
        email: 'maria@honeychain.io',
        phone: '+15551234567',
        role: 'PACKAGING',
        organizationName: 'Cascade Pure Bottling Unit',
        facilityLocation: 'Portland Distribution Park, OR',
        licenseNumber: 'FSSAI-PKG-2026-1184',
      );
      expect(completePkg.isProfileComplete, true);
    });

  });
}
