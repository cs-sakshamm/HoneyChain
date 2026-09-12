import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { isUserProfileComplete, PROFILE_INCOMPLETE_RESPONSE } from './services/profileService';

const prisma = new PrismaClient();

async function runProfileGateTests() {
  console.log('🧪 Starting HoneyChain Profile Gate End-to-End Verification Tests...\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, testName: string) {
    totalTests++;
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passedTests++;
    } else {
      console.error(`  ❌ FAIL: ${testName}`);
      throw new Error(`Test failed: ${testName}`);
    }
  }

  // 1. Test Harvester Profile Logic
  console.log('── 1. Testing Harvester Profile Logic ──');
  const incompleteHarvester = {
    name: 'Incomplete Harvester',
    email: '',
    phone: '',
    role: 'HARVESTER'
  };
  assert(!isUserProfileComplete(incompleteHarvester), 'Incomplete Harvester (missing email & phone) is rejected');

  const completeHarvester = {
    name: 'Licensed Harvester',
    email: 'harvester@honeychain.io',
    phone: '+1 (555) 234-5678',
    role: 'HARVESTER'
  };
  assert(isUserProfileComplete(completeHarvester), 'Complete Harvester (name, email, phone) is accepted');

  // 2. Test Collection & Processing Profile Logic
  console.log('\n── 2. Testing Collection & Processing Profile Logic ──');
  const incompleteProcessor = {
    name: 'Processor User',
    phone: '+1 (555) 345-6789',
    email: 'processor@honeychain.io',
    role: 'COLLECTOR_PROCESSOR',
    organizationName: '',
    facilityLocation: '',
    licenseNumber: ''
  };
  assert(!isUserProfileComplete(incompleteProcessor), 'Incomplete Processor (missing organization, facility location, license) is rejected');

  const completeProcessor = {
    name: 'Cascade Processing Manager',
    phone: '+1 (555) 345-6789',
    email: 'processor@honeychain.io',
    role: 'COLLECTOR_PROCESSOR',
    organizationName: 'Cascade Honey Processing Ltd.',
    facilityLocation: 'Bend Industrial Park, OR',
    licenseNumber: 'FSSAI-PROC-2026-9812'
  };
  assert(isUserProfileComplete(completeProcessor), 'Complete Processor (name, phone, email, organization, location, license) is accepted');

  // 3. Test Lab Testing Profile Logic
  console.log('\n── 3. Testing Lab Testing Profile Logic ──');
  const incompleteLab = {
    name: 'Lab Officer',
    phone: '+1 (555) 456-7890',
    email: 'lab@honeychain.io',
    role: 'LAB_TESTING',
    organizationName: '',
    facilityLocation: '',
    licenseNumber: ''
  };
  assert(!isUserProfileComplete(incompleteLab), 'Incomplete Lab (missing lab name, lab address, accreditation) is rejected');

  const completeLab = {
    name: 'Dr. Evelyn Vance',
    phone: '+1 (555) 456-7890',
    email: 'lab@honeychain.io',
    role: 'LAB_TESTING',
    organizationName: 'Pacific Pure Apiculture Labs',
    facilityLocation: 'Corvallis Tech Campus, OR',
    licenseNumber: 'LAB-ACCRED-2026-4402'
  };
  assert(isUserProfileComplete(completeLab), 'Complete Lab (authorized name, phone, email, lab name, address, accreditation) is accepted');

  // 4. Test Packaging Profile Logic
  console.log('\n── 4. Testing Packaging Profile Logic ──');
  const incompletePackager = {
    name: 'Packager Officer',
    phone: '+1 (555) 567-8901',
    email: 'packager@honeychain.io',
    role: 'PACKAGING',
    organizationName: '',
    facilityLocation: '',
    licenseNumber: ''
  };
  assert(!isUserProfileComplete(incompletePackager), 'Incomplete Packager (missing packaging unit, facility location, FSSAI license) is rejected');

  const completePackager = {
    name: 'Marcus Sterling',
    phone: '+1 (555) 567-8901',
    email: 'packaging@honeychain.io',
    role: 'PACKAGING',
    organizationName: 'Artisan Honey Packaging Co.',
    facilityLocation: 'Portland Logistics Hub, OR',
    licenseNumber: 'FSSAI-PKG-2026-1184'
  };
  assert(isUserProfileComplete(completePackager), 'Complete Packager (authorized name, phone, email, company, location, license) is accepted');

  // 5. Test Database Operations & Workflow Restriction with Prisma
  console.log('\n── 5. Testing Database User Lifecycle & Profile State ──');

  // Create an incomplete user in DB
  const testIncompleteUser = await prisma.user.upsert({
    where: { email: 'test-incomplete@honeychain.io' },
    update: {
      name: 'Unknown Incomplete',
      phone: '',
      organizationName: null,
      facilityLocation: null,
      licenseNumber: null,
      role: 'COLLECTOR_PROCESSOR'
    },
    create: {
      id: 'test-incomplete-user-id',
      name: 'Unknown Incomplete',
      email: 'test-incomplete@honeychain.io',
      phone: '',
      role: 'COLLECTOR_PROCESSOR'
    }
  });

  assert(!isUserProfileComplete(testIncompleteUser), 'Database loaded incomplete user is evaluated as incomplete');

  // Update user with complete profile data
  const testCompletedUser = await prisma.user.update({
    where: { id: testIncompleteUser.id },
    data: {
      name: 'Alex Rivera',
      phone: '+1 (555) 888-9999',
      organizationName: 'Rivera Honey Extraction & Processing',
      facilityLocation: 'Eugene Hub, OR',
      licenseNumber: 'FSSAI-PROC-2026-7711'
    }
  });

  assert(isUserProfileComplete(testCompletedUser), 'Database updated user with required fields is evaluated as complete');

  // 6. Test Error Response Format
  console.log('\n── 6. Testing Standardized Incomplete Profile Error Response ──');
  assert(PROFILE_INCOMPLETE_RESPONSE.code === 'PROFILE_INCOMPLETE', 'Error code matches PROFILE_INCOMPLETE');
  assert(PROFILE_INCOMPLETE_RESPONSE.success === false, 'Error response success is false');
  assert(PROFILE_INCOMPLETE_RESPONSE.message.includes('complete your profile'), 'Error message prompts profile completion');

  console.log(`\n🎉 All ${totalTests}/${totalTests} Profile Gate Verification Tests PASSED successfully!`);
}

runProfileGateTests()
  .catch((err) => {
    console.error('Fatal error during test run:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
