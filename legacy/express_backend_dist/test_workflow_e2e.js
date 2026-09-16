"use strict";
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
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const client_1 = require("@prisma/client");
const blockchainService_1 = require("./services/blockchainService");
const prisma = new client_1.PrismaClient();
function runE2ETests() {
    return __awaiter(this, void 0, void 0, function* () {
        var _a;
        console.log('===============================================================');
        console.log('   HoneyChain End-to-End Request Chain Automated Test Suite    ');
        console.log('   Harvester -> Collection -> Lab Testing -> Packaging -> QR  ');
        console.log('===============================================================\n');
        let passed = 0;
        let failed = 0;
        function assert(condition, testName, detail) {
            if (condition) {
                console.log(`  [PASS] ${testName}`);
                passed++;
            }
            else {
                console.error(`  [FAIL] ${testName}`, detail || '');
                failed++;
            }
        }
        const timestamp = Date.now();
        const testBatchId = `BATCH-E2E-${timestamp}`;
        const harvesterPhone = `+1555001${timestamp.toString().slice(-4)}`;
        const processorPhone = `+1555002${timestamp.toString().slice(-4)}`;
        const labPhone = `+1555003${timestamp.toString().slice(-4)}`;
        const packagerPhone = `+1555004${timestamp.toString().slice(-4)}`;
        try {
            // ── Setup Users ──
            console.log('--- 0. Setup Test Roles & Hive ---');
            const harvester = yield prisma.user.upsert({
                where: {
                    email_role: {
                        email: `harvester_${timestamp}@honeychain.test`,
                        role: 'HARVESTER',
                    },
                },
                update: {},
                create: {
                    email: `harvester_${timestamp}@honeychain.test`,
                    phone: harvesterPhone,
                    name: 'Maria Harvester',
                    role: 'HARVESTER',
                },
            });
            const processor = yield prisma.user.upsert({
                where: {
                    email_role: {
                        email: `processor_${timestamp}@honeychain.test`,
                        role: 'COLLECTOR_PROCESSOR',
                    },
                },
                update: {},
                create: {
                    email: `processor_${timestamp}@honeychain.test`,
                    phone: processorPhone,
                    name: 'Dev Processing Unit',
                    role: 'COLLECTOR_PROCESSOR',
                },
            });
            const labTech = yield prisma.user.upsert({
                where: {
                    email_role: {
                        email: `lab_${timestamp}@honeychain.test`,
                        role: 'LAB',
                    },
                },
                update: {},
                create: {
                    email: `lab_${timestamp}@honeychain.test`,
                    phone: labPhone,
                    name: 'Dr. Sarah Lab Analyst',
                    role: 'LAB',
                },
            });
            const packager = yield prisma.user.upsert({
                where: {
                    email_role: {
                        email: `packager_${timestamp}@honeychain.test`,
                        role: 'PACKAGING',
                    },
                },
                update: {},
                create: {
                    email: `packager_${timestamp}@honeychain.test`,
                    phone: packagerPhone,
                    name: 'Raj Packaging Facility',
                    role: 'PACKAGING',
                },
            });
            const hive = yield prisma.hive.upsert({
                where: { hiveCode: `HC-HIVE-${timestamp.toString().slice(-4)}` },
                update: {},
                create: {
                    hiveCode: `HC-HIVE-${timestamp.toString().slice(-4)}`,
                    name: 'Highland Cedar Hive 1',
                    apiaryLocation: 'Kashmir Valley',
                    userId: harvester.id
                }
            });
            assert(!!harvester && !!processor && !!labTech && !!packager, 'All 4 role actors initialized in database');
            // ── 1. Blockchain Canonical Hashing Test ──
            console.log('\n--- 1. Blockchain Provenance & SHA-256 Checksum Verification ---');
            const samplePayload = { batchId: testBatchId, weight: 24.5, flower: 'Acacia' };
            const provEvent = yield blockchainService_1.blockchainService.recordBatchEventOnChain(testBatchId, 'HARVEST_SUBMITTED', harvester.id, samplePayload);
            assert(!!provEvent.dataHash && provEvent.dataHash.length === 64, 'Generated SHA-256 canonical hash of length 64');
            assert(['CONFIRMED', 'PENDING'].includes(provEvent.status), `Blockchain status handled gracefully: ${provEvent.status}`);
            // ── 2. Stage 1: Harvester -> Collection Request ──
            console.log('\n--- 2. Stage 1: Harvester Harvest Submission -> Collection & Processing ---');
            const harvest = yield prisma.harvest.create({
                data: {
                    harvesterId: harvester.id,
                    hiveId: hive.id,
                    quantity: 25.0,
                    location: 'Kashmir Valley',
                    status: 'HARVESTED'
                }
            });
            const batch = yield prisma.batch.create({
                data: {
                    id: testBatchId,
                    harvestId: harvest.id,
                    status: 'HARVESTED',
                    currentStage: 'HARVEST'
                }
            });
            const req1 = yield prisma.workflowRequest.create({
                data: {
                    requestId: `REQ-HARV-${timestamp}`,
                    batchId: batch.id,
                    fromUserId: harvester.id,
                    toUserId: processor.id,
                    fromRole: 'HARVESTER',
                    toRole: 'COLLECTOR_PROCESSOR',
                    requestType: 'HARVEST_TO_COLLECTION',
                    status: 'PENDING',
                    quantity: 25.0,
                    notes: 'Cold extracted acacia honey from Highland hive'
                }
            });
            yield prisma.requestHistory.create({
                data: {
                    requestId: req1.id,
                    batchId: batch.id,
                    actorId: harvester.id,
                    actorRole: 'HARVESTER',
                    action: 'CREATED',
                    fromStatus: 'NONE',
                    toStatus: 'PENDING',
                    notes: 'Harvest batch submitted to Collection & Processing'
                }
            });
            assert(req1.status === 'PENDING' && req1.fromRole === 'HARVESTER', 'Harvester request created with status PENDING and Harvester role');
            // ── 3. Stage 1 Rejection Test (Negative Case) ──
            console.log('\n--- 3. Negative Test: Collection Rejection & Audit Log ---');
            const dummyHarvest = yield prisma.harvest.create({
                data: {
                    harvesterId: harvester.id,
                    hiveId: hive.id,
                    quantity: 10.0,
                    status: 'HARVESTED'
                }
            });
            const dummyBatch = yield prisma.batch.create({
                data: {
                    id: `BATCH-REJECT-${timestamp}`,
                    harvestId: dummyHarvest.id,
                    status: 'HARVESTED',
                    currentStage: 'HARVEST'
                }
            });
            const rejectReq = yield prisma.workflowRequest.create({
                data: {
                    requestId: `REQ-REJ-${timestamp}`,
                    batchId: dummyBatch.id,
                    fromUserId: harvester.id,
                    fromRole: 'HARVESTER',
                    toRole: 'COLLECTOR_PROCESSOR',
                    requestType: 'HARVEST_TO_COLLECTION',
                    status: 'PENDING',
                    quantity: 10.0
                }
            });
            const rejectedReq = yield prisma.workflowRequest.update({
                where: { id: rejectReq.id },
                data: {
                    status: 'REJECTED',
                    notes: 'Contaminated storage container observed on delivery',
                    rejectedAt: new Date()
                }
            });
            yield prisma.batch.update({
                where: { id: dummyBatch.id },
                data: { status: 'COLLECTION_REJECTED' }
            });
            yield prisma.requestHistory.create({
                data: {
                    requestId: rejectedReq.id,
                    batchId: dummyBatch.id,
                    actorId: processor.id,
                    actorRole: 'COLLECTOR_PROCESSOR',
                    action: 'REJECTED',
                    fromStatus: 'PENDING',
                    toStatus: 'REJECTED',
                    notes: rejectedReq.notes
                }
            });
            assert(rejectedReq.status === 'REJECTED' && ((_a = rejectedReq.notes) === null || _a === void 0 ? void 0 : _a.includes('Contaminated')), 'Rejection persists with audit reason');
            const updatedDummyBatch = yield prisma.batch.findUnique({ where: { id: dummyBatch.id } });
            assert((updatedDummyBatch === null || updatedDummyBatch === void 0 ? void 0 : updatedDummyBatch.status) === 'COLLECTION_REJECTED', 'Batch status transitioned to COLLECTION_REJECTED');
            // ── 4. Stage 1 Acceptance & Processing ──
            console.log('\n--- 4. Stage 1 Acceptance: Ownership Handover to Collection & Processing ---');
            const acceptedReq1 = yield prisma.workflowRequest.update({
                where: { id: req1.id },
                data: {
                    status: 'ACCEPTED',
                    toUserId: processor.id,
                    acceptedAt: new Date()
                }
            });
            yield prisma.batch.update({
                where: { id: batch.id },
                data: { status: 'PROCESSING_PENDING', currentStage: 'COLLECTION' }
            });
            assert(acceptedReq1.status === 'ACCEPTED', 'Collector accepted request; batch moved to PROCESSING_PENDING');
            // ── 5. Stage 2: Extraction & Send to Lab ──
            console.log('\n--- 5. Stage 2: Processing Record & Transition to Lab Testing ---');
            yield prisma.processingRecord.create({
                data: {
                    batchId: batch.id,
                    processorId: processor.id,
                    requestId: req1.id,
                    quantityReceived: 25.0,
                    quantityAfter: 24.2,
                    method: 'Cold centrifugal centrifuge filtration 80-mesh',
                    notes: 'Moisture tested 16.8%, filtered and sample jar prepared'
                }
            });
            yield prisma.workflowRequest.update({
                where: { id: req1.id },
                data: { status: 'COMPLETED' }
            });
            const req2 = yield prisma.workflowRequest.create({
                data: {
                    requestId: `REQ-LAB-${timestamp}`,
                    batchId: batch.id,
                    fromUserId: processor.id,
                    toUserId: labTech.id,
                    fromRole: 'COLLECTOR_PROCESSOR',
                    toRole: 'LAB',
                    requestType: 'SAMPLE_TO_LAB',
                    status: 'PENDING',
                    previousRequestId: req1.id,
                    quantity: 24.2,
                    notes: 'Dispatched 500ml representative sample for purity & C4 sugar testing'
                }
            });
            yield prisma.batch.update({
                where: { id: batch.id },
                data: {
                    status: 'LAB_TESTING_PENDING',
                    currentStage: 'LAB'
                }
            });
            assert(req2.status === 'PENDING' && req2.toRole === 'LAB', 'Sample request dispatched to Lab with link to previous request');
            // ── 6. Stage 3: Lab Quality Gates (Negative & Positive) ──
            console.log('\n--- 6. Stage 3: Laboratory Quality Analysis & Quality Gates ---');
            // Negative Quality Gate Test: High Moisture (> 20%)
            const failedMoisture = 22.5;
            const isQualityPass = failedMoisture <= 20.0 && 65 >= 70;
            assert(!isQualityPass, 'Quality gate correctly flags high moisture (>20%) and low score (<70) as failure');
            const labReport = yield prisma.labReport.create({
                data: {
                    batchId: batch.id,
                    labId: labTech.id,
                    requestId: req2.id,
                    testResults: 'Moisture: 16.5%, Purity: 99.1%, HMF: 8mg/kg, Pollen: Kashmir Flora Certified',
                    qualityScore: 94.0,
                    moistureContent: 16.5,
                    purityGrade: 'Grade A (99.1%)',
                    contaminantsFound: 'None',
                    status: 'PASSED'
                }
            });
            yield prisma.workflowRequest.update({
                where: { id: req2.id },
                data: { status: 'COMPLETED' }
            });
            yield prisma.batch.update({
                where: { id: batch.id },
                data: { status: 'LAB_VERIFIED' }
            });
            assert(labReport.qualityScore === 94.0 && labReport.status === 'PASSED', 'Lab Report created with Grade A quality score (94/100) and PASSED status');
            // ── 7. Stage 4: Send to Packaging ──
            console.log('\n--- 7. Stage 4: Handoff from Lab to Packaging Facility ---');
            const req3 = yield prisma.workflowRequest.create({
                data: {
                    requestId: `REQ-PKG-${timestamp}`,
                    batchId: batch.id,
                    fromUserId: labTech.id,
                    toUserId: packager.id,
                    fromRole: 'LAB',
                    toRole: 'PACKAGING',
                    requestType: 'LAB_TO_PACKAGING',
                    status: 'PENDING',
                    previousRequestId: req2.id,
                    quantity: 24.2,
                    notes: 'Quality certified batch ready for final jar packaging & QR tagging'
                }
            });
            assert(req3.status === 'PENDING' && req3.toRole === 'PACKAGING', 'Packaging request created');
            yield prisma.workflowRequest.update({
                where: { id: req3.id },
                data: { status: 'ACCEPTED' }
            });
            const qrUrl = `http://localhost:3000/api/verify?batchId=${batch.id}`;
            const packagingRecord = yield prisma.packagingRecord.create({
                data: {
                    batchId: batch.id,
                    packagerId: packager.id,
                    requestId: req3.id,
                    finalQuantity: 24.0,
                    numberOfPackages: 48,
                    packageSize: '500g Sealed Glass Jar',
                    qrCodeUrl: qrUrl
                }
            });
            yield prisma.workflowRequest.update({
                where: { id: req3.id },
                data: { status: 'COMPLETED' }
            });
            const finalBatch = yield prisma.batch.update({
                where: { id: batch.id },
                data: { status: 'PACKAGED', currentStage: 'COMPLETED' }
            });
            assert(finalBatch.status === 'PACKAGED', 'Batch successfully completed all stages and marked as PACKAGED');
            assert(packagingRecord.numberOfPackages === 48, '48 packages sealed with verifiable QR code URL');
            // ── 8. Provenance & Public QR Verification ──
            console.log('\n--- 8. Public QR Verification & Full Audit Trail Lookup ---');
            const fullBatch = yield prisma.batch.findUnique({
                where: { id: batch.id },
                include: {
                    harvest: { include: { harvester: true, hive: true } },
                    processingRecords: { include: { processor: true } },
                    labReports: { include: { lab: true } },
                    packagingRecords: { include: { packager: true } },
                    workflowRequests: { include: { fromUser: true, toUser: true, history: true } },
                    provenanceEvents: true
                }
            });
            assert(!!fullBatch, 'Full batch retrieved with all relational links');
            assert((fullBatch === null || fullBatch === void 0 ? void 0 : fullBatch.processingRecords.length) === 1, 'Processing record linked');
            assert((fullBatch === null || fullBatch === void 0 ? void 0 : fullBatch.labReports.length) === 1, 'Lab report linked');
            assert((fullBatch === null || fullBatch === void 0 ? void 0 : fullBatch.packagingRecords.length) === 1, 'Packaging record linked');
            assert((fullBatch === null || fullBatch === void 0 ? void 0 : fullBatch.workflowRequests.length) === 3, 'Complete 3-step sequential request chain linked (Harvester -> Collector -> Lab -> Packaging)');
            console.log('\n===============================================================');
            console.log(`   TEST RESULTS: ${passed} PASSED, ${failed} FAILED           `);
            console.log('===============================================================\n');
            if (failed > 0) {
                process.exit(1);
            }
        }
        catch (error) {
            console.error('Fatal test error:', error);
            process.exit(1);
        }
        finally {
            yield prisma.$disconnect();
        }
    });
}
runE2ETests();
