import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/profile/controllers/user_controller.dart';

void main() {
  group('Role-Based Profile Completion Unit Tests', () {
    test('Harvester profile completion logic', () {
      // Incomplete: missing email & phone
      const inc1 = UserProfile(
        name: 'John Beekeeper',
        email: '',
        phone: '',
        role: 'HARVESTER',
      );
      expect(inc1.isProfileComplete, isFalse);

      // Incomplete: default/unknown name
      const inc2 = UserProfile(
        name: 'Unknown',
        email: 'john@honeychain.io',
        phone: '+1 555-0199',
        role: 'HARVESTER',
      );
      expect(inc2.isProfileComplete, isFalse);

      // Complete Harvester
      const completeHarvester = UserProfile(
        name: 'John Beekeeper',
        email: 'john@honeychain.io',
        phone: '+1 555-0199',
        role: 'HARVESTER',
      );
      expect(completeHarvester.isProfileComplete, isTrue);
    });

    test('Collection & Processing profile completion logic', () {
      // Incomplete: missing organization and license
      const inc = UserProfile(
        name: 'Collector User',
        email: 'collector@honeychain.io',
        phone: '+1 555-0200',
        role: 'COLLECTOR_PROCESSOR',
      );
      expect(inc.isProfileComplete, isFalse);

      // Complete Collection & Processing
      const completeCollector = UserProfile(
        name: 'Cascade Processing Manager',
        email: 'collector@honeychain.io',
        phone: '+1 555-0200',
        role: 'COLLECTOR_PROCESSOR',
        organizationName: 'Cascade Honey Processing Ltd.',
        facilityLocation: 'Bend Industrial Park, OR',
        licenseNumber: 'FSSAI-PROC-2026-9812',
      );
      expect(completeCollector.isProfileComplete, isTrue);
    });

    test('Lab Testing profile completion logic', () {
      // Incomplete: missing lab accreditation & location
      const inc = UserProfile(
        name: 'Dr. Evelyn Vance',
        email: 'lab@honeychain.io',
        phone: '+1 555-0300',
        role: 'LAB',
      );
      expect(inc.isProfileComplete, isFalse);

      // Complete Lab Testing
      const completeLab = UserProfile(
        name: 'Dr. Evelyn Vance',
        email: 'lab@honeychain.io',
        phone: '+1 555-0300',
        role: 'LAB',
        organizationName: 'Pacific Pure Apiculture Labs',
        facilityLocation: 'Corvallis Tech Campus, OR',
        licenseNumber: 'LAB-ACCRED-2026-4402',
      );
      expect(completeLab.isProfileComplete, isTrue);
    });

    test('Packaging profile completion logic', () {
      // Incomplete: missing packaging facility info & FSSAI license
      const inc = UserProfile(
        name: 'Marcus Sterling',
        email: 'packaging@honeychain.io',
        phone: '+1 555-0400',
        role: 'PACKAGING',
      );
      expect(inc.isProfileComplete, isFalse);

      // Complete Packaging
      const completePackager = UserProfile(
        name: 'Marcus Sterling',
        email: 'packaging@honeychain.io',
        phone: '+1 555-0400',
        role: 'PACKAGING',
        organizationName: 'Artisan Honey Packaging Co.',
        facilityLocation: 'Portland Logistics Hub, OR',
        licenseNumber: 'FSSAI-PKG-2026-1184',
      );
      expect(completePackager.isProfileComplete, isTrue);
    });
  });
}
