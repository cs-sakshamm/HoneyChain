import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { isUserProfileComplete, PROFILE_INCOMPLETE_RESPONSE, BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE } from './services/profileService';
import { generateUniqueBeekeeperId } from './routes/authRoutes';

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

  const testIncompleteUser = await prisma.user.upsert({
    where: {
      email_role: {
        email: 'test-incomplete@honeychain.io',
        role: 'COLLECTOR_PROCESSOR',
      },
    },
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
  assert(BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE.code === 'PROFILE_INCOMPLETE', 'Beekeeper error code matches PROFILE_INCOMPLETE');
  assert(BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE.message === 'Please complete your beekeeper profile before adding a hive.', 'Beekeeper error message matches exact requirement: Please complete your beekeeper profile before adding a hive.');

  // 7. Test Beekeeper & Beehive Uniqueness & Ownership Isolation
  console.log('\n── 7. Testing Beekeeper & Beehive Uniqueness & Constraints ──');
  // Clean up any test users from previous runs
  await prisma.hive.deleteMany({
    where: {
      user: {
        email: {
          in: ['bk_incomplete@honeychain.io', 'bk_alpha@honeychain.io', 'bk_beta@honeychain.io']
        }
      }
    }
  });
  await prisma.user.deleteMany({
    where: {
      email: {
        in: ['bk_incomplete@honeychain.io', 'bk_alpha@honeychain.io', 'bk_beta@honeychain.io']
      }
    }
  });

  const beekeeperIdA = await generateUniqueBeekeeperId();
  const beekeeperA = await prisma.user.create({
    data: {
      name: 'Beekeeper Alice',
      email: 'bk_alpha@honeychain.io',
      phone: '+1 (555) 111-2222',
      role: 'HARVESTER',
      beekeeperId: beekeeperIdA
    }
  });
  assert(Boolean(beekeeperA.id), 'Beekeeper Alice created with unique database ID');
  assert(/^HC-BK-[0-9A-F]{8}$/.test(beekeeperA.beekeeperId || ''), 'Beekeeper Alice has valid HC-BK-XXXXXXXX formatted ID');

  const beekeeperIdB = await generateUniqueBeekeeperId();
  const beekeeperB = await prisma.user.create({
    data: {
      name: 'Beekeeper Bob',
      email: 'bk_beta@honeychain.io',
      phone: '+1 (555) 333-4444',
      role: 'HARVESTER',
      beekeeperId: beekeeperIdB
    }
  });
  assert(Boolean(beekeeperB.id) && beekeeperA.id !== beekeeperB.id, 'Beekeeper Bob created with distinct unique ID');
  assert(beekeeperA.beekeeperId !== beekeeperB.beekeeperId, 'Beekeeper Alice and Bob have distinct collision-resistant Beekeeper IDs');

  // Test duplicate beekeeperId rejection in DB
  let duplicateBkrRejected = false;
  try {
    await prisma.user.create({
      data: {
        name: 'Duplicate Beekeeper',
        email: 'duplicate_bkr@honeychain.io',
        phone: '+1 (555) 999-0000',
        role: 'HARVESTER',
        beekeeperId: beekeeperIdA // duplicate
      }
    });
  } catch (err) {
    duplicateBkrRejected = true;
  }
  assert(duplicateBkrRejected, 'Database rejects duplicate beekeeperId via @unique constraint');

  // Generate unique codes and create hives
  const hex1 = crypto.randomBytes(3).toString('hex').toUpperCase();
  const codeA1 = `HIVE-${hex1}`;
  const hiveA1 = await prisma.hive.create({
    data: {
      userId: beekeeperA.id,
      name: 'Meadow Alpha',
      hiveCode: codeA1,
      apiaryLocation: 'Sunny Meadow',
      hiveType: 'Langstroth',
      colonyStrength: 'Strong',
      beeBreed: 'Italian',
      overallHealth: 'Healthy'
    }
  });

  const hex2 = crypto.randomBytes(3).toString('hex').toUpperCase();
  const codeA2 = `HIVE-${hex2}`;
  const hiveA2 = await prisma.hive.create({
    data: {
      userId: beekeeperA.id,
      name: 'Meadow Beta',
      hiveCode: codeA2,
      apiaryLocation: 'Sunny Meadow',
      hiveType: 'Top-Bar',
      colonyStrength: 'Moderate',
      beeBreed: 'Carniolan',
      overallHealth: 'Healthy'
    }
  });

  assert(hiveA1.id !== hiveA2.id, 'Two hives for same beekeeper have distinct unique IDs');
  assert(hiveA1.hiveCode !== hiveA2.hiveCode, 'Two hives for same beekeeper have distinct unique Hive Codes');
  assert(/^HIVE-[0-9A-F]{6}$/.test(hiveA1.hiveCode), 'Hive A1 matches HIVE-XXXXXX format');
  assert(/^HIVE-[0-9A-F]{6}$/.test(hiveA2.hiveCode), 'Hive A2 matches HIVE-XXXXXX format');
  assert(hiveA1.userId === beekeeperA.id, 'Hive 1 is strictly associated with Beekeeper Alice');
  assert(hiveA2.userId === beekeeperA.id, 'Hive 2 is strictly associated with Beekeeper Alice');

  const hex3 = crypto.randomBytes(3).toString('hex').toUpperCase();
  const codeB1 = `HIVE-${hex3}`;
  const hiveB1 = await prisma.hive.create({
    data: {
      userId: beekeeperB.id,
      name: 'Valley Hive 1',
      hiveCode: codeB1,
      apiaryLocation: 'River Valley',
      hiveType: 'Langstroth',
      colonyStrength: 'Strong',
      beeBreed: 'Buckfast',
      overallHealth: 'Healthy'
    }
  });

  assert(hiveB1.id !== hiveA1.id && hiveB1.id !== hiveA2.id, 'Hive for Beekeeper Bob has unique ID distinct from Alice hives');
  assert(hiveB1.userId === beekeeperB.id, 'Hive B1 is strictly associated with Beekeeper Bob');

  // Test duplicate hiveCode database constraint
  let duplicateRejected = false;
  try {
    await prisma.hive.create({
      data: {
        userId: beekeeperB.id,
        name: 'Conflict Hive',
        hiveCode: hiveA1.hiveCode, // duplicate
        apiaryLocation: 'Conflict Area'
      }
    });
  } catch (err) {
    duplicateRejected = true;
  }
  assert(duplicateRejected, 'Database rejects duplicate hiveCode via @unique constraint');

  // Query isolation
  const aliceHives = await prisma.hive.findMany({ where: { userId: beekeeperA.id } });
  const bobHives = await prisma.hive.findMany({ where: { userId: beekeeperB.id } });
  assert(aliceHives.length === 2, 'Alice query returns exactly her 2 hives');
  assert(bobHives.length === 1, 'Bob query returns exactly his 1 hive');

  // Clean up test data
  await prisma.hive.deleteMany({
    where: {
      userId: { in: [beekeeperA.id, beekeeperB.id] }
    }
  });
  await prisma.user.deleteMany({
    where: {
      id: { in: [beekeeperA.id, beekeeperB.id] }
    }
  });

  console.log(`\n🎉 All ${totalTests}/${totalTests} Profile Gate & Beekeeper/Hive Uniqueness Tests PASSED successfully!`);
}

runProfileGateTests()
  .catch((err) => {
    console.error('Fatal error during test run:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

