"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const assert_1 = __importDefault(require("assert"));
const client_1 = require("@prisma/client");
const crypto = __importStar(require("crypto"));
const geoService_1 = require("./services/geoService");
const prisma = new client_1.PrismaClient();
function runE2ETest() {
    return __awaiter(this, void 0, void 0, function* () {
        var _a, _b;
        console.log('🧪 Starting Full HoneyChain 5-Stage Supply Chain E2E Test Suite...\n');
        const now = new Date();
        const testRunSuffix = crypto.randomBytes(3).toString('hex').toUpperCase();
        const permanentTraceabilityId = `HC-2026-${testRunSuffix}`;
        console.log(`📌 Permanent Supply Chain Traceability ID: ${permanentTraceabilityId}\n`);
        // ── Setup Actor Users ──
        const harvesterUser = yield prisma.user.findFirst({ where: { role: 'HARVESTER' } });
        (0, assert_1.default)(harvesterUser, 'Harvester user exists');
        const collectorUser = yield prisma.user.findFirst({ where: { role: 'COLLECTOR_PROCESSOR' } });
        (0, assert_1.default)(collectorUser, 'Collector user exists');
        const labUser = yield prisma.user.findFirst({ where: { role: 'LAB' } });
        (0, assert_1.default)(labUser, 'Lab user exists');
        const packagerUser = yield prisma.user.findFirst({ where: { role: 'PACKAGING' } });
        (0, assert_1.default)(packagerUser, 'Packager user exists');
        // ── 1. Harvester: Create Hive & Harvest ──
        console.log('--- 1. Harvester: Create Hive & Initial Harvest ---');
        const hive = yield prisma.hive.create({
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
        (0, assert_1.default)(hive.id, 'Hive created successfully in database');
        const harvest = yield prisma.harvest.create({
            data: {
                harvesterId: harvesterUser.id,
                hiveId: hive.id,
                quantity: 35.5,
                location: hive.apiaryLocation,
                notes: 'Clean spring harvest from high altitude flora'
            }
        });
        (0, assert_1.default)(harvest.id, 'Harvest created successfully');
        const batch = yield prisma.batch.create({
            data: {
                id: permanentTraceabilityId,
                harvestId: harvest.id,
                status: 'HARVESTED',
                currentStage: 'HARVEST'
            }
        });
        assert_1.default.strictEqual(batch.id, permanentTraceabilityId, 'Batch initialized with permanent Traceability ID');
        console.log(`  ✅ PASS: Hive, Harvest & Batch initialized (${batch.id})`);
        // ── 2. Harvester: Nearest Collection Centres Query & Distance Calculation ──
        console.log('\n--- 2. Harvester: Nearest Collection & Processing Centres Matching ---');
        const collectors = yield prisma.user.findMany({
            where: { role: 'COLLECTOR_PROCESSOR' },
            include: { collectorVerification: true }
        });
        (0, assert_1.default)(collectors.length > 0, 'Found registered collection centers');
        const originCoords = (0, geoService_1.parseCoordinates)(hive.apiaryLocation) || { lat: 44.0521, lng: -121.3153 };
        const sortedCollectors = collectors.map((c) => {
            var _a;
            const loc = c.facilityLocation || ((_a = c.collectorVerification) === null || _a === void 0 ? void 0 : _a.facilityLocation) || 'Bend Industrial Center, OR';
            const coords = (0, geoService_1.parseCoordinates)(loc) || { lat: 44.0582, lng: -121.3153 };
            const distanceKm = (0, geoService_1.calculateHaversineDistanceKm)(originCoords.lat, originCoords.lng, coords.lat, coords.lng);
            return Object.assign(Object.assign({}, c), { distanceKm });
        }).sort((a, b) => a.distanceKm - b.distanceKm);
        console.log('  Nearest Collection Centres:');
        sortedCollectors.forEach((c, idx) => {
            console.log(`    ${idx + 1}. ${c.name} (${c.facilityLocation}) -> ${c.distanceKm} km away`);
        });
        (0, assert_1.default)(sortedCollectors[0].distanceKm <= sortedCollectors[1].distanceKm, 'Centres are sorted in ascending distance order');
        console.log('  ✅ PASS: Distance-based nearest matching verified for Collection Centres');
        const targetCollector = sortedCollectors[0];
        // ── 3. Harvester: Send Request to Selected Collection Centre ──
        console.log('\n--- 3. Harvester: Send Workflow Request to Nearest Collection Centre ---');
        const req1 = yield prisma.workflowRequest.create({
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
        (0, assert_1.default)(req1.id, 'Harvest request created');
        assert_1.default.strictEqual(req1.toUserId, targetCollector.id, 'Request targeted to selected collection center');
        console.log(`  ✅ PASS: Request created: ${req1.requestId} for Batch: ${req1.batchId}`);
        // ── 4. Collection & Processing: Accept Request & Process ──
        console.log('\n--- 4. Collection & Processing: Accept Request & Extract ---');
        const acceptedReq1 = yield prisma.workflowRequest.update({
            where: { id: req1.id },
            data: {
                status: 'ACCEPTED',
                acceptedAt: now
            }
        });
        assert_1.default.strictEqual(acceptedReq1.status, 'ACCEPTED', 'Request accepted by Collector');
        // Create Processing Record
        const procRecord = yield prisma.processingRecord.create({
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
        (0, assert_1.default)(procRecord.id, 'Processing record saved');
        yield prisma.workflowRequest.update({
            where: { id: req1.id },
            data: { status: 'COMPLETED', completedAt: now }
        });
        console.log('  ✅ PASS: Harvest accepted, processed (34.8 kg extracted), and marked COMPLETED');
        // ── 5. Collection & Processing: Nearest Lab Centres & Send to Lab ──
        console.log('\n--- 5. Collection: Nearest Lab Testing Centres Matching ---');
        const labs = yield prisma.user.findMany({
            where: { role: 'LAB' },
            include: { labVerification: true }
        });
        const collectorCoords = (0, geoService_1.parseCoordinates)(targetCollector.facilityLocation) || { lat: 44.0582, lng: -121.3153 };
        const sortedLabs = labs.map((l) => {
            var _a;
            const loc = l.facilityLocation || ((_a = l.labVerification) === null || _a === void 0 ? void 0 : _a.labAddress) || 'Corvallis Tech Campus, OR';
            const coords = (0, geoService_1.parseCoordinates)(loc) || { lat: 44.5646, lng: -123.2620 };
            const distanceKm = (0, geoService_1.calculateHaversineDistanceKm)(collectorCoords.lat, collectorCoords.lng, coords.lat, coords.lng);
            return Object.assign(Object.assign({}, l), { distanceKm });
        }).sort((a, b) => a.distanceKm - b.distanceKm);
        console.log('  Nearest Lab Testing Centres:');
        sortedLabs.forEach((l, idx) => {
            console.log(`    ${idx + 1}. ${l.name} -> ${l.distanceKm} km away`);
        });
        const targetLab = sortedLabs[0];
        const req2 = yield prisma.workflowRequest.create({
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
        assert_1.default.strictEqual(req2.batchId, permanentTraceabilityId, 'Traceability ID maintained in Stage 2');
        console.log(`  ✅ PASS: Lab Request created: ${req2.requestId} (Traceability: ${req2.batchId})`);
        // ── 6. Lab Tester: Accept & Conduct Full 6-Parameter Quality Test ──
        console.log('\n--- 6. Lab Tester: Accept Sample & Submit 6-Parameter Quality Report ---');
        yield prisma.workflowRequest.update({
            where: { id: req2.id },
            data: { status: 'ACCEPTED', acceptedAt: now }
        });
        const labReport = yield prisma.labReport.create({
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
        (0, assert_1.default)(labReport.id, 'Lab report saved with full individual parameters');
        yield prisma.workflowRequest.update({
            where: { id: req2.id },
            data: { status: 'VERIFIED', completedAt: now }
        });
        console.log(`  ✅ PASS: Full 6-parameter lab test submitted and marked VERIFIED (Report: ${labReport.reportId})`);
        // ── 7. Lab: Nearest Packaging Centres & Forward to Packaging ──
        console.log('\n--- 7. Lab Tester: Nearest Packaging Centres Matching ---');
        const packagers = yield prisma.user.findMany({
            where: { role: 'PACKAGING' },
            include: { packagingVerification: true }
        });
        const labCoords = (0, geoService_1.parseCoordinates)(targetLab.facilityLocation) || { lat: 44.5646, lng: -123.2620 };
        const sortedPackagers = packagers.map((p) => {
            var _a;
            const loc = p.facilityLocation || ((_a = p.packagingVerification) === null || _a === void 0 ? void 0 : _a.facilityLocation) || 'Portland Logistics Hub, OR';
            const coords = (0, geoService_1.parseCoordinates)(loc) || { lat: 45.5231, lng: -122.6765 };
            const distanceKm = (0, geoService_1.calculateHaversineDistanceKm)(labCoords.lat, labCoords.lng, coords.lat, coords.lng);
            return Object.assign(Object.assign({}, p), { distanceKm });
        }).sort((a, b) => a.distanceKm - b.distanceKm);
        console.log('  Nearest Packaging Centres:');
        sortedPackagers.forEach((p, idx) => {
            console.log(`    ${idx + 1}. ${p.name} -> ${p.distanceKm} km away`);
        });
        const targetPackager = sortedPackagers[0];
        const req3 = yield prisma.workflowRequest.create({
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
        assert_1.default.strictEqual(req3.batchId, permanentTraceabilityId, 'Traceability ID maintained in Stage 3');
        console.log(`  ✅ PASS: Packaging Request created: ${req3.requestId}`);
        // ── 8. Packaging Centre: Accept, Finalize Packaging & Generate QR ──
        console.log('\n--- 8. Packaging Centre: Finalize Packaging & Issue Consumer QR ---');
        yield prisma.workflowRequest.update({
            where: { id: req3.id },
            data: { status: 'ACCEPTED', acceptedAt: now }
        });
        const qrCodeUrl = `https://honeychain.io/verify?batch=${encodeURIComponent(permanentTraceabilityId)}`;
        const pkgRecord = yield prisma.packagingRecord.create({
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
        (0, assert_1.default)(pkgRecord.id, 'Packaging record created');
        yield prisma.workflowRequest.update({
            where: { id: req3.id },
            data: { status: 'COMPLETED', completedAt: now }
        });
        yield prisma.batch.update({
            where: { id: permanentTraceabilityId },
            data: { status: 'COMPLETED', currentStage: 'COMPLETED' }
        });
        console.log(`  ✅ PASS: Packaging finalized (70 jars of 500g) and Batch COMPLETED`);
        // ── 9. Verification & Audit Trail Validation ──
        console.log('\n--- 9. Public Traceability & End-to-End Verification Check ---');
        const verifiedBatch = yield prisma.batch.findUnique({
            where: { id: permanentTraceabilityId },
            include: {
                harvest: { include: { harvester: true, hive: true } },
                workflowRequests: { include: { fromUser: true, toUser: true } },
                processingRecords: true,
                labReports: true,
                packagingRecords: true
            }
        });
        (0, assert_1.default)(verifiedBatch, 'Batch exists');
        assert_1.default.strictEqual(verifiedBatch.status, 'COMPLETED', 'Batch status is COMPLETED');
        assert_1.default.strictEqual((_a = verifiedBatch.harvest.hive) === null || _a === void 0 ? void 0 : _a.hiveCode, `HIVE-${testRunSuffix}`, 'Traces back to exact origin Hive');
        assert_1.default.strictEqual(verifiedBatch.processingRecords.length, 1, 'Processing record linked');
        assert_1.default.strictEqual(verifiedBatch.labReports[0].overallResult, 'PASS', 'Lab report linked with PASS result');
        assert_1.default.strictEqual(verifiedBatch.labReports[0].moistureValue, 16.5, 'Exact moisture parameter preserved');
        assert_1.default.strictEqual(verifiedBatch.labReports[0].hmfValue, 11.8, 'Exact HMF parameter preserved');
        assert_1.default.strictEqual(verifiedBatch.packagingRecords[0].numberOfPackages, 70, 'Packaging record linked');
        assert_1.default.strictEqual(verifiedBatch.workflowRequests.length, 3, 'Complete 3-step sequential request chain intact');
        console.log(`  ✅ PASS: Unified Traceability Chain verified:`);
        console.log(`     🌱 Hive (${(_b = verifiedBatch.harvest.hive) === null || _b === void 0 ? void 0 : _b.name})`);
        console.log(`     🍯 Harvest (${verifiedBatch.harvest.quantity} kg by ${verifiedBatch.harvest.harvester.name})`);
        console.log(`     🏭 Processing (${verifiedBatch.processingRecords[0].method})`);
        console.log(`     🧪 Lab Testing (${verifiedBatch.labReports[0].qualityScore}/100 Grade A PASS)`);
        console.log(`     📦 Packaging (${verifiedBatch.packagingRecords[0].numberOfPackages} jars)`);
        console.log(`     ✓ Final QR URL (${pkgRecord.qrCodeUrl})`);
        console.log('\n🎉 ALL 9/9 Full Supply-Chain Connection Tests PASSED Successfully!');
    });
}
runE2ETest().catch((err) => {
    console.error('❌ E2E Test failed:', err);
    process.exit(1);
}).finally(() => {
    prisma.$disconnect();
});
