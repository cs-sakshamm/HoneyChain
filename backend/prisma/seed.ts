import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting HoneyChain PostgreSQL database seed...');

  // 1. Seed or find default demo harvester user
  const harvesterUser = await prisma.user.upsert({
    where: { email: 'operations@honeychain.io' },
    update: {
      name: 'HoneyChain Apiary Manager',
      phone: '+1 (555) 234-5678',
      role: 'HARVESTER',
      bsid: 'BSID-2026-A1B2C3D4',
      bspPass: 'BSP-2026-E5F6'
    },
    create: {
      id: 'user-default-harvester',
      name: 'HoneyChain Apiary Manager',
      email: 'operations@honeychain.io',
      phone: '+1 (555) 234-5678',
      role: 'HARVESTER',
      bsid: 'BSID-2026-A1B2C3D4',
      bspPass: 'BSP-2026-E5F6'
    }
  });
  console.log(`✓ Seeded Harvester User: ${harvesterUser.name} (${harvesterUser.email})`);

  // 2. Seed default Processor, Lab, and Packager users for workflow testing
  const processorUser = await prisma.user.upsert({
    where: { email: 'processor@honeychain.io' },
    update: {
      phone: '+1 (555) 345-6789',
      organizationName: 'Cascade Honey Processing Ltd.',
      facilityLocation: 'Bend Industrial Park, OR',
      licenseNumber: 'FSSAI-PROC-2026-9812',
      designation: 'Operations Director'
    },
    create: {
      id: 'user-default-processor',
      name: 'Cascade Processing Facility',
      email: 'processor@honeychain.io',
      phone: '+1 (555) 345-6789',
      role: 'COLLECTION_PROCESSING',
      organizationName: 'Cascade Honey Processing Ltd.',
      facilityLocation: 'Bend Industrial Park, OR',
      licenseNumber: 'FSSAI-PROC-2026-9812',
      designation: 'Operations Director'
    }
  });

  const labUser = await prisma.user.upsert({
    where: { email: 'lab@honeychain.io' },
    update: {
      phone: '+1 (555) 456-7890',
      organizationName: 'Pacific Pure Apiculture Labs',
      facilityLocation: 'Corvallis Tech Campus, OR',
      licenseNumber: 'LAB-ACCRED-2026-4402',
      designation: 'Chief Analytical Chemist'
    },
    create: {
      id: 'user-default-lab',
      name: 'Pacific Pure Apiculture Labs',
      email: 'lab@honeychain.io',
      phone: '+1 (555) 456-7890',
      role: 'LAB_TESTING',
      organizationName: 'Pacific Pure Apiculture Labs',
      facilityLocation: 'Corvallis Tech Campus, OR',
      licenseNumber: 'LAB-ACCRED-2026-4402',
      designation: 'Chief Analytical Chemist'
    }
  });

  const packagerUser = await prisma.user.upsert({
    where: { email: 'packaging@honeychain.io' },
    update: {
      phone: '+1 (555) 567-8901',
      organizationName: 'Artisan Honey Packaging Co.',
      facilityLocation: 'Portland Logistics Hub, OR',
      licenseNumber: 'FSSAI-PKG-2026-1184',
      designation: 'Packaging Line Supervisor'
    },
    create: {
      id: 'user-default-packager',
      name: 'Artisan Honey Packaging Co.',
      email: 'packaging@honeychain.io',
      phone: '+1 (555) 567-8901',
      role: 'PACKAGING',
      organizationName: 'Artisan Honey Packaging Co.',
      facilityLocation: 'Portland Logistics Hub, OR',
      licenseNumber: 'FSSAI-PKG-2026-1184',
      designation: 'Packaging Line Supervisor'
    }
  });
  console.log(`✓ Seeded Supply Chain Partner Users (Processor, Lab, Packager) with full profile details`);

  // 3. (Optional) No dummy hives are seeded - hives are created genuine by beekeepers

  // 4. Seed Harvester Verification Record
  const now = new Date();
  await prisma.harvesterVerification.upsert({
    where: { harvesterId: harvesterUser.id },
    update: {},
    create: {
      harvesterId: harvesterUser.id,
      governmentIdType: 'NATIONAL_ID',
      governmentIdReference: 'DOC-NAT-***9481',
      governmentIdDocHash: crypto.createHash('sha256').update('DL-98421094').digest('hex'),
      governmentIdVerified: 'Verified',
      governmentIdSubmittedAt: now,
      mobileNumber: '+1 (555) 234-5678',
      mobileVerified: 'Verified',
      mobileVerifiedAt: now,
      registrationId: 'BK-OR-8842',
      registrationType: 'STATE_REGISTRY',
      registrationVerified: 'Verified',
      registrationSubmittedAt: now,
      apiaryName: 'Cascade High Mountain Apiary',
      apiaryLocation: 'Cascade Valley, OR',
      apiaryCoordinates: '44.0521° N, 121.3153° W',
      locationVerified: 'Verified',
      locationSubmittedAt: now,
      verificationStatus: 'Verified',
      verificationId: 'HV-2026-F98B2A1C',
      verificationHash: crypto.createHash('sha256').update('HV-2026-F98B2A1C-CANONICAL').digest('hex'),
      blockchainNetwork: 'HoneyChain Provenance Ledger',
      transactionHash: '0x3f1e8a9d2c4b5e7f01a2b3c4d5e6f7a8b9c0d1e2',
      blockNumber: 1042,
      verifiedAt: now
    }
  });
  console.log(`✓ Seeded Harvester Verification (ID: HV-2026-F98B2A1C)`);

  // 5. No dummy harvest/batch seeded - workflow requests are created genuine by users

  console.log('✅ PostgreSQL database seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
