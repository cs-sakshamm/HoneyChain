import assert from 'assert';
import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { calculateHaversineDistanceKm, parseCoordinates } from './services/geoService';

const prisma = new PrismaClient();

async function runE2ETest() {
  console.log('🧪 Starting Full HoneyChain 5-Stage Supply Chain E2E Test Suite...\n');

  const now = new Date();
  const testRunSuffix = crypto.randomBytes(3).toString('hex').toUpperCase();
  const permanentTraceabilityId = `HC-2026-${testRunSuffix}`;

  console.log(`📌 Permanent Supply Chain Traceability ID: ${permanentTraceabilityId}\n`);

  // ── Setup Actor Users ──
  const harvesterUser = await prisma.user.findFirst({ where: { role: 'HARVESTER' } });
  assert(harvesterUser, 'Harvester user exists');

  const collectorUser = await prisma.user.findFirst({ where: { role: 'COLLECTOR_PROCESSOR' } });
  assert(collectorUser, 'Collector user exists');

  const labUser = await prisma.user.findFirst({ where: { role: 'LAB' } });
  assert(labUser, 'Lab user exists');

  const packagerUser = await prisma.user.findFirst({ where: { role: 'PACKAGING' } });
  assert(packagerUser, 'Packager user exists');

  // ── 1. Harvester: Create Hive & Harvest ──
  console.log('--- 1. Harvester: Create Hive & Initial Harvest ---');
  const hive = await prisma.hive.create({
    data: {
      userId: harvesterUser.id,
      name: `Alpine Apiary Hive #${testRunSuffix}`,
      hiveCode: `HIVE-${testRunSuffix}`,
      apiaryLocation: 'Cascade Valley, OR (44.0521, -121.3153)',
      hiveType: 'Langstroth',
      honeyType: 'Wild Mountain Floral',
      queenStatus: 'Mated',
      colonyStrength: 'Strong'
    }
  });
  assert(hive.id, 'Hive created successfully in database');

  const harvest = await prisma.harvest.create({
    data: {
      harvesterId: harvesterUser.id,
      hiveId: hive.id,
      quantity: 35.5,
      location: hive.apiaryLocation,
      notes: 'Clean spring harvest from high altitude flora'
    }
  });
  assert(harvest.id, 'Harvest created successfully');

  const batch = await prisma.batch.create({
    data: {
      id: permanentTraceabilityId,
      harvestId: harvest.id,
      status: 'HARVESTED',
      currentStage: 'HARVEST'
    }
  });
  assert.strictEqual(batch.id, permanentTraceabilityId, 'Batch initialized with permanent Traceability ID');
  console.log(`  ✅ PASS: Hive, Harvest & Batch initialized (${batch.id})`);

  // ── 2. Harvester: Nearest Collection Centres Query & Distance Calculation ──
  console.log('\n--- 2. Harvester: Nearest Collection & Processing Centres Matching ---');
  const collectors = await prisma.user.findMany({
    where: { role: 'COLLECTOR_PROCESSOR' },
    include: { collectorVerification: true }
  });
  assert(collectors.length > 0, 'Found registered collection centers');

  const originCoords = parseCoordinates(hive.apiaryLocation) || { lat: 44.0521, lng: -121.3153 };
  const sortedCollectors = collectors.map((c) => {
    const loc = c.facilityLocation || c.collectorVerification?.facilityLocation || 'Bend Industrial Center, OR';
    const coords = parseCoordinates(loc) || { lat: 44.0582, lng: -121.3153 };
    const distanceKm = calculateHaversineDistanceKm(originCoords.lat, originCoords.lng, coords.lat, coords.lng);
    return { ...c, distanceKm };
  }).sort((a, b) => a.distanceKm - b.distanceKm);

  console.log('  Nearest Collection Centres:');
  sortedCollectors.forEach((c, idx) => {
    console.log(`    ${idx + 1}. ${c.name} (${c.facilityLocation}) -> ${c.distanceKm} km away`);
  });

  assert(sortedCollectors[0].distanceKm <= sortedCollectors[1].distanceKm, 'Centres are sorted in ascending distance order');
  console.log('  ✅ PASS: Distance-based nearest matching verified for Collection Centres');

  const targetCollector = sortedCollectors[0];

  // ── 3. Harvester: Send Request to Selected Collection Centre ──
  console.log('\n--- 3. Harvester: Send Workflow Request to Nearest Collection Centre ---');
  const req1 = await prisma.workflowRequest.create({
    data: {
      requestId: `REQ-COL-2026-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
      batchId: permanentTraceabilityId,
      fromUserId: harvesterUser.id,
      toUserId: targetCollector.id,
      fromRole: 'HARVESTER',
      toRole: 'COLLECTOR_PROCESSOR',
      requestType: 'HARVEST_TO_COLLECTION',
      status: 'PENDING',
      quantity: 35.5,
      notes: 'Dispatched to nearest cold extraction center'
    }
  });
  assert(req1.id, 'Harvest request created');
  assert.strictEqual(req1.toUserId, targetCollector.id, 'Request targeted to selected collection center');
  console.log(`  ✅ PASS: Request created: ${req1.requestId} for Batch: ${req1.batchId}`);

  // ── 4. Collection & Processing: Accept Request & Process ──
  console.log('\n--- 4. Collection & Processing: Accept Request & Extract ---');
  const acceptedReq1 = await prisma.workflowRequest.update({
    where: { id: req1.id },
    data: {
      status: 'ACCEPTED',
      acceptedAt: now
    }
  });
  assert.strictEqual(acceptedReq1.status, 'ACCEPTED', 'Request accepted by Collector');

  // Create Processing Record
  const procRecord = await prisma.processingRecord.create({
    data: {
      batchId: permanentTraceabilityId,
      processorId: targetCollector.id,
      requestId: req1.id,
      quantityReceived: 35.5,
      quantityAfter: 34.8,
      method: 'Triple-Filtered Cold Centrifugation',
      moistureAtReceipt: 16.9,
      notes: 'Extraction completed under sterile ISO conditions'
    }
  });
  assert(procRecord.id, 'Processing record saved');

  await prisma.workflowRequest.update({
    where: { id: req1.id },
    data: { status: 'COMPLETED', completedAt: now }
  });
  console.log('  ✅ PASS: Harvest accepted, processed (34.8 kg extracted), and marked COMPLETED');

  // ── 5. Collection & Processing: Nearest Lab Centres & Send to Lab ──
  console.log('\n--- 5. Collection: Nearest Lab Testing Centres Matching ---');
  const labs = await prisma.user.findMany({
    where: { role: 'LAB' },
    include: { labVerification: true }
  });
  const collectorCoords = parseCoordinates(targetCollector.facilityLocation) || { lat: 44.0582, lng: -121.3153 };
  const sortedLabs = labs.map((l) => {
    const loc = l.facilityLocation || l.labVerification?.labAddress || 'Corvallis Tech Campus, OR';
    const coords = parseCoordinates(loc) || { lat: 44.5646, lng: -123.2620 };
    const distanceKm = calculateHaversineDistanceKm(collectorCoords.lat, collectorCoords.lng, coords.lat, coords.lng);
    return { ...l, distanceKm };
  }).sort((a, b) => a.distanceKm - b.distanceKm);

  console.log('  Nearest Lab Testing Centres:');
  sortedLabs.forEach((l, idx) => {
    console.log(`    ${idx + 1}. ${l.name} -> ${l.distanceKm} km away`);
  });

  const targetLab = sortedLabs[0];
  const req2 = await prisma.workflowRequest.create({
    data: {
      requestId: `REQ-LAB-2026-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
      batchId: permanentTraceabilityId,
      fromUserId: targetCollector.id,
      toUserId: targetLab.id,
      fromRole: 'COLLECTOR_PROCESSOR',
      toRole: 'LAB',
      requestType: 'COLLECTION_TO_LAB',
      status: 'PENDING',
      previousRequestId: req1.id,
      quantity: 34.8,
      notes: 'Extracted sample sent for HPLC & spectrometry analysis'
    }
  });
  assert.strictEqual(req2.batchId, permanentTraceabilityId, 'Traceability ID maintained in Stage 2');
  console.log(`  ✅ PASS: Lab Request created: ${req2.requestId} (Traceability: ${req2.batchId})`);

  // ── 6. Lab Tester: Accept & Conduct Full 6-Parameter Quality Test ──
  console.log('\n--- 6. Lab Tester: Accept Sample & Submit 6-Parameter Quality Report ---');
  await prisma.workflowRequest.update({
    where: { id: req2.id },
    data: { status: 'ACCEPTED', acceptedAt: now }
  });

  const labReport = await prisma.labReport.create({
    data: {
      reportId: `LAB-RPT-2026-${testRunSuffix}`,
      qrTraceabilityId: permanentTraceabilityId,
      batchId: permanentTraceabilityId,
      labId: targetLab.id,
      requestId: req2.id,
      testResults: 'Physicochemical & Spectrometry Analysis: All Parameters PASS',
      qualityScore: 97.5,
      moistureContent: 16.5,
      purityGrade: 'Grade A Pure',
      contaminantsFound: 'None',
      status: 'APPROVED',
      overallResult: 'PASS',
      moistureValue: 16.5,
      moistureLimit: '<= 20.0%',
      moistureStatus: 'PASS',
      hmfValue: 11.8,
      hmfLimit: '<= 40.0 mg/kg',
      hmfStatus: 'PASS',
      diastaseValue: 15.1,
      diastaseLimit: '>= 8.0 Schade Units',
      diastaseStatus: 'PASS',
      purityValue: 1.18,
      purityLimit: '>= 0.95 F/G Ratio',
      purityStatus: 'PASS',
      residuesValue: 'None Detected (< 0.01 ppm)',
      residuesLimit: '0.0 ppm',
      residuesStatus: 'PASS',
      pollenValue: 'Authentic Wild Mountain Flora (Apis mellifera)',
      pollenLimit: 'Botanical Origin Authentic',
      pollenStatus: 'PASS',
      labTesterName: 'Lead Chemist Dr. Evelyn Reed',
      labName: targetLab.name,
      testDate: now,
      sampleCode: `SMP-${testRunSuffix}`,
      remarks: 'Certified 100% Pure Raw Honey conforming to Codex & FSSAI standards.'
    }
  });
  assert(labReport.id, 'Lab report saved with full individual parameters');

  await prisma.workflowRequest.update({
    where: { id: req2.id },
    data: { status: 'VERIFIED', completedAt: now }
  });
  console.log(`  ✅ PASS: Full 6-parameter lab test submitted and marked VERIFIED (Report: ${labReport.reportId})`);

  // ── 7. Lab: Nearest Packaging Centres & Forward to Packaging ──
  console.log('\n--- 7. Lab Tester: Nearest Packaging Centres Matching ---');
  const packagers = await prisma.user.findMany({
    where: { role: 'PACKAGING' },
    include: { packagingVerification: true }
  });
  const labCoords = parseCoordinates(targetLab.facilityLocation) || { lat: 44.5646, lng: -123.2620 };
  const sortedPackagers = packagers.map((p) => {
    const loc = p.facilityLocation || p.packagingVerification?.facilityLocation || 'Portland Logistics Hub, OR';
    const coords = parseCoordinates(loc) || { lat: 45.5231, lng: -122.6765 };
    const distanceKm = calculateHaversineDistanceKm(labCoords.lat, labCoords.lng, coords.lat, coords.lng);
    return { ...p, distanceKm };
  }).sort((a, b) => a.distanceKm - b.distanceKm);

  console.log('  Nearest Packaging Centres:');
  sortedPackagers.forEach((p, idx) => {
    console.log(`    ${idx + 1}. ${p.name} -> ${p.distanceKm} km away`);
  });

  const targetPackager = sortedPackagers[0];
  const req3 = await prisma.workflowRequest.create({
    data: {
      requestId: `REQ-PKG-2026-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
      batchId: permanentTraceabilityId,
      fromUserId: targetLab.id,
      toUserId: targetPackager.id,
      fromRole: 'LAB',
      toRole: 'PACKAGING',
      requestType: 'LAB_TO_PACKAGING',
      status: 'PENDING',
      previousRequestId: req2.id,
      quantity: 34.8,
      notes: 'Lab-certified batch ready for tamper-evident bottling and QR generation'
    }
  });
  assert.strictEqual(req3.batchId, permanentTraceabilityId, 'Traceability ID maintained in Stage 3');
  console.log(`  ✅ PASS: Packaging Request created: ${req3.requestId}`);

  // ── 8. Packaging Centre: Accept, Finalize Packaging & Generate QR ──
  console.log('\n--- 8. Packaging Centre: Finalize Packaging & Issue Consumer QR ---');
  await prisma.workflowRequest.update({
    where: { id: req3.id },
    data: { status: 'ACCEPTED', acceptedAt: now }
  });

  const qrCodeUrl = `https://honeychain.io/verify?batch=${encodeURIComponent(permanentTraceabilityId)}`;
  const pkgRecord = await prisma.packagingRecord.create({
    data: {
      batchId: permanentTraceabilityId,
      packagerId: targetPackager.id,
      requestId: req3.id,
      finalQuantity: 34.8,
      numberOfPackages: 70,
      packageSize: '500g Glass Jar (Tamper-Evident Seal)',
      qrCodeUrl,
      notes: 'Packaged in cleanroom ISO facility with induction seal and digital provenance QR'
    }
  });
  assert(pkgRecord.id, 'Packaging record created');

  await prisma.workflowRequest.update({
    where: { id: req3.id },
    data: { status: 'COMPLETED', completedAt: now }
  });

  await prisma.batch.update({
    where: { id: permanentTraceabilityId },
    data: { status: 'COMPLETED', currentStage: 'COMPLETED' }
  });
  console.log(`  ✅ PASS: Packaging finalized (70 jars of 500g) and Batch COMPLETED`);

  // ── 9. Verification & Audit Trail Validation ──
  console.log('\n--- 9. Public Traceability & End-to-End Verification Check ---');
  const verifiedBatch = await prisma.batch.findUnique({
    where: { id: permanentTraceabilityId },
    include: {
      harvest: { include: { harvester: true, hive: true } },
      workflowRequests: { include: { fromUser: true, toUser: true } },
      processingRecords: true,
      labReports: true,
      packagingRecords: true
    }
  });

  assert(verifiedBatch, 'Batch exists');
  assert.strictEqual(verifiedBatch.status, 'COMPLETED', 'Batch status is COMPLETED');
  assert.strictEqual(verifiedBatch.harvest.hive?.hiveCode, `HIVE-${testRunSuffix}`, 'Traces back to exact origin Hive');
  assert.strictEqual(verifiedBatch.processingRecords.length, 1, 'Processing record linked');
  assert.strictEqual(verifiedBatch.labReports[0].overallResult, 'PASS', 'Lab report linked with PASS result');
  assert.strictEqual(verifiedBatch.labReports[0].moistureValue, 16.5, 'Exact moisture parameter preserved');
  assert.strictEqual(verifiedBatch.labReports[0].hmfValue, 11.8, 'Exact HMF parameter preserved');
  assert.strictEqual(verifiedBatch.packagingRecords[0].numberOfPackages, 70, 'Packaging record linked');
  assert.strictEqual(verifiedBatch.workflowRequests.length, 3, 'Complete 3-step sequential request chain intact');

  console.log(`  ✅ PASS: Unified Traceability Chain verified:`);
  console.log(`     🌱 Hive (${verifiedBatch.harvest.hive?.name})`);
  console.log(`     🍯 Harvest (${verifiedBatch.harvest.quantity} kg by ${verifiedBatch.harvest.harvester.name})`);
  console.log(`     🏭 Processing (${verifiedBatch.processingRecords[0].method})`);
  console.log(`     🧪 Lab Testing (${verifiedBatch.labReports[0].qualityScore}/100 Grade A PASS)`);
  console.log(`     📦 Packaging (${verifiedBatch.packagingRecords[0].numberOfPackages} jars)`);
  console.log(`     ✓ Final QR URL (${pkgRecord.qrCodeUrl})`);

  console.log('\n🎉 ALL 9/9 Full Supply-Chain Connection Tests PASSED Successfully!');
}

runE2ETest().catch((err) => {
  console.error('❌ E2E Test failed:', err);
  process.exit(1);
}).finally(() => {
  prisma.$disconnect();
});
