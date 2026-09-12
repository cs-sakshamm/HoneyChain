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
    update: {},
    create: {
      id: 'user-default-processor',
      name: 'Cascade Processing Facility',
      email: 'processor@honeychain.io',
      role: 'COLLECTION_PROCESSING'
    }
  });

  const labUser = await prisma.user.upsert({
    where: { email: 'lab@honeychain.io' },
    update: {},
    create: {
      id: 'user-default-lab',
      name: 'Pacific Pure Apiculture Labs',
      email: 'lab@honeychain.io',
      role: 'LAB_TESTING'
    }
  });

  const packagerUser = await prisma.user.upsert({
    where: { email: 'packaging@honeychain.io' },
    update: {},
    create: {
      id: 'user-default-packager',
      name: 'Artisan Honey Packaging Co.',
      email: 'packaging@honeychain.io',
      role: 'PACKAGING'
    }
  });
  console.log(`✓ Seeded Supply Chain Partner Users (Processor, Lab, Packager)`);

  // 3. Seed Initial Hives into PostgreSQL
  const now = new Date();
  const sampleHives = [
    {
      id: 'hive_sample_1',
      userId: harvesterUser.id,
      name: 'Hive Alpha',
      hiveCode: 'H-001',
      apiaryLocation: 'Main Apiary',
      hiveType: 'Langstroth',
      dateAdded: new Date(now.getTime() - 120 * 24 * 60 * 60 * 1000),
      queenStatus: 'Mated',
      totalFrames: 10,
      broodFrames: 6,
      colonyStrength: 'Strong',
      queenAgeMonths: 12,
      beeBreed: 'Italian',
      expectedProductionKg: 35.0,
      previousYearProductionKg: 25.0,
      currentYearProductionKg: 28.0,
      honeyType: 'Wildflower',
      lastInspectionDate: new Date(2026, 8, 8),
      miteStatus: 'Low',
      diseaseStatus: 'None',
      feedingRequired: false,
      queenCondition: 'Excellent',
      overallHealth: 'Healthy',
      notes: 'Strong brood pattern observed across 6 frames. Honey supers filled consistently. Regular inspection logged clean.',
    },
    {
      id: 'hive_sample_2',
      userId: harvesterUser.id,
      name: 'Hive Beta',
      hiveCode: 'H-002',
      apiaryLocation: 'North Meadow Apiary',
      hiveType: 'Langstroth',
      dateAdded: new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000),
      queenStatus: 'Mated',
      totalFrames: 10,
      broodFrames: 4,
      colonyStrength: 'Moderate',
      queenAgeMonths: 18,
      beeBreed: 'Carniolan',
      expectedProductionKg: 30.0,
      previousYearProductionKg: 22.0,
      currentYearProductionKg: 18.0,
      honeyType: 'Clover',
      lastInspectionDate: new Date(2026, 8, 4),
      miteStatus: 'Medium',
      diseaseStatus: 'None',
      feedingRequired: true,
      queenCondition: 'Good',
      overallHealth: 'Needs Attention',
      notes: 'Slightly lower brood density. Mite count slightly elevated; organic oxalic acid treatment scheduled.',
    },
    {
      id: 'hive_sample_3',
      userId: harvesterUser.id,
      name: 'Hive Gamma',
      hiveCode: 'H-003',
      apiaryLocation: 'Riverbank Apiary',
      hiveType: 'Flow Hive',
      dateAdded: new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000),
      queenStatus: 'Re-queened',
      totalFrames: 8,
      broodFrames: 5,
      colonyStrength: 'Strong',
      queenAgeMonths: 6,
      beeBreed: 'Buckfast',
      expectedProductionKg: 40.0,
      previousYearProductionKg: 32.0,
      currentYearProductionKg: 36.0,
      honeyType: 'Acacia',
      lastInspectionDate: new Date(2026, 8, 2),
      miteStatus: 'Low',
      diseaseStatus: 'None',
      feedingRequired: false,
      queenCondition: 'Excellent',
      overallHealth: 'Healthy',
      notes: 'Recently re-queened with pure Buckfast stock. High foraging activity and calm temperament.',
    }
  ];

  for (const hiveData of sampleHives) {
    await prisma.hive.upsert({
      where: { hiveCode: hiveData.hiveCode },
      update: hiveData,
      create: hiveData
    });
  }
  console.log(`✓ Seeded ${sampleHives.length} Hives in PostgreSQL`);

  // 4. Seed Harvester Verification Record
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

  // 5. Seed Initial Harvest & Batch
  const existingBatch = await prisma.batch.findUnique({ where: { id: 'HC-BATCH-2026-001' } });
  if (!existingBatch) {
    const harvest = await prisma.harvest.create({
      data: {
        id: 'harvest-seed-001',
        harvesterId: harvesterUser.id,
        hiveId: 'hive_sample_1',
        quantity: 28.5,
        unit: 'kg',
        location: 'Cascade Valley, OR',
        status: 'HARVESTED',
        notes: 'High clarity, low moisture raw wildflower harvest.'
      }
    });

    const batch = await prisma.batch.create({
      data: {
        id: 'HC-BATCH-2026-001',
        harvestId: harvest.id,
        status: 'HARVESTED'
      }
    });

    await prisma.provenanceEvent.create({
      data: {
        batchId: batch.id,
        eventType: 'HARVEST_CREATED',
        actorId: harvesterUser.id,
        dataHash: crypto.createHash('sha256').update(JSON.stringify(harvest)).digest('hex'),
        status: 'CONFIRMED',
        network: 'HoneyChain Provenance Ledger'
      }
    });
    console.log(`✓ Seeded Initial Batch: ${batch.id}`);
  }

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
