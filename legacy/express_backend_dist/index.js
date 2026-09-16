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
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const client_1 = require("@prisma/client");
const ethers_1 = require("ethers");
const crypto = __importStar(require("crypto"));
const authRoutes_1 = __importDefault(require("./routes/authRoutes"));
const hiveRoutes_1 = __importDefault(require("./routes/hiveRoutes"));
const telemetryRoutes_1 = __importDefault(require("./routes/telemetryRoutes"));
const verificationRoutes_1 = __importDefault(require("./routes/verificationRoutes"));
const workflowRoutes_1 = __importDefault(require("./routes/workflowRoutes"));
const verificationService_1 = require("./services/verificationService");
const profileService_1 = require("./services/profileService");
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
const prisma = new client_1.PrismaClient();
// ── 7-Day Telemetry Cleanup Task ──
// Deletes telemetry older than 7 days to prevent database bloat, keeps alerts.
const cleanupOldTelemetry = () => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const result = yield prisma.hiveTelemetry.deleteMany({
            where: {
                recordedAt: { lt: sevenDaysAgo }
            }
        });
        if (result.count > 0) {
            console.log(`🧹 [Telemetry Cleanup] Deleted ${result.count} telemetry records older than 7 days.`);
        }
    }
    catch (error) {
        console.error(`❌ [Telemetry Cleanup] Error:`, error);
    }
});
// Run on startup, then every 24 hours
cleanupOldTelemetry();
setInterval(cleanupOldTelemetry, 24 * 60 * 60 * 1000);
// Blockchain configuration
const PRIVATE_KEY = process.env.BLOCKCHAIN_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Account 0 on Hardhat Localhost
const PROVIDER_URL = process.env.BLOCKCHAIN_PROVIDER_URL || 'http://127.0.0.1:8545';
const contractAddress = process.env.CONTRACT_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const provider = new ethers_1.ethers.JsonRpcProvider(PROVIDER_URL, undefined, { staticNetwork: true });
const wallet = new ethers_1.ethers.Wallet(PRIVATE_KEY, provider);
const contractAbi = [
    "function recordEvent(string memory batchId, string memory eventType, string memory actorId, string memory dataHash, string memory previousEventHash) public",
    "event ProvenanceRecorded(string indexed batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)"
];
const contract = new ethers_1.ethers.Contract(contractAddress, contractAbi, wallet);
// Helper function to record event on blockchain
function recordOnBlockchain(batchId, eventType, actorId, dataObj) {
    return __awaiter(this, void 0, void 0, function* () {
        const dataString = JSON.stringify(dataObj);
        const dataHash = crypto.createHash('sha256').update(dataString).digest('hex');
        // Create pending event in DB
        let provEvent = yield prisma.provenanceEvent.create({
            data: {
                batchId,
                eventType,
                actorId,
                dataHash,
                status: 'PENDING'
            }
        });
        try {
            const tx = yield contract.recordEvent(batchId, eventType, actorId, dataHash, "");
            const receipt = yield tx.wait();
            // Update DB with success
            provEvent = yield prisma.provenanceEvent.update({
                where: { id: provEvent.id },
                data: {
                    txHash: receipt.hash,
                    blockNumber: receipt.blockNumber,
                    status: 'CONFIRMED'
                }
            });
        }
        catch (error) {
            console.warn("[Blockchain] Transaction not committed on chain (node might be offline):", (error === null || error === void 0 ? void 0 : error.message) || error);
            provEvent = yield prisma.provenanceEvent.update({
                where: { id: provEvent.id },
                data: { status: 'FAILED' }
            });
        }
        return provEvent;
    });
}
// Ensure actor user exists in PostgreSQL to satisfy foreign key constraints
function ensureUserExists(userIdOrName_1) {
    return __awaiter(this, arguments, void 0, function* (userIdOrName, defaultRole = 'HARVESTER') {
        let user = yield prisma.user.findFirst({
            where: {
                OR: [
                    { id: userIdOrName },
                    { name: userIdOrName },
                    { email: userIdOrName }
                ]
            },
            include: {
                harvesterVerification: true
            }
        });
        if (!user) {
            const safeId = userIdOrName.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
            user = yield prisma.user.create({
                data: {
                    name: userIdOrName,
                    email: `${safeId}@honeychain.io`,
                    role: defaultRole
                },
                include: {
                    harvesterVerification: true
                }
            });
        }
        return user;
    });
}
// ── Health Check (PostgreSQL Status) ──
app.get('/api/health', (_req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        yield prisma.$queryRaw `SELECT 1`;
        res.json({
            status: 'healthy',
            database: 'PostgreSQL connected',
            timestamp: new Date().toISOString()
        });
    }
    catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            database: 'PostgreSQL connection failed',
            error: (error === null || error === void 0 ? void 0 : error.message) || String(error)
        });
    }
}));
// ── Mount Modular Routes ──
app.use('/api/auth', authRoutes_1.default);
app.use('/api', authRoutes_1.default); // Exposes /api/profile and /api/profile/identity
app.use('/api/hives', hiveRoutes_1.default);
app.use('/api/telemetry', telemetryRoutes_1.default);
app.use('/api/verification', verificationRoutes_1.default);
app.use('/api', verificationRoutes_1.default); // Exposes /api/verify/harvester/:verificationId directly
app.use('/api', workflowRoutes_1.default); // Exposes /api/requests, /api/batches, /api/lab-reports, /api/packaging
// ── 1. Create Harvest & Batch ──
app.post('/api/harvests', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { harvesterId, hiveId, quantity, location, notes } = req.body;
    try {
        const actorUser = yield ensureUserExists(harvesterId || 'Harvester', 'HARVESTER');
        if (!(0, profileService_1.isUserProfileComplete)(actorUser)) {
            return res.status(403).json(profileService_1.PROFILE_INCOMPLETE_RESPONSE);
        }
        if (actorUser.role === 'HARVESTER' && !(0, profileService_1.isHarvesterFullyVerified)(actorUser.harvesterVerification)) {
            return res.status(403).json(profileService_1.HARVESTER_VERIFICATION_REQUIRED_RESPONSE);
        }
        const harvest = yield prisma.harvest.create({
            data: {
                harvesterId: actorUser.id,
                hiveId: hiveId || null,
                quantity: Number(quantity) || 0.0,
                location: location || 'Main Apiary',
                notes: notes || '',
                status: "HARVESTED"
            }
        });
        const batchId = `HC-BATCH-2026-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
        const batch = yield prisma.batch.create({
            data: { id: batchId, harvestId: harvest.id, status: "HARVESTED" }
        });
        const prov = yield recordOnBlockchain(batchId, "HARVEST_CREATED", actorUser.id, harvest);
        res.json({ harvest, batch, prov });
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 2. Create Chain Request ──
app.post('/api/chain-requests', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { batchId, requesterId } = req.body;
    try {
        const actorUser = yield ensureUserExists(requesterId || 'Requester', 'COLLECTION_PROCESSING');
        if (!(0, profileService_1.isUserProfileComplete)(actorUser)) {
            return res.status(403).json(profileService_1.PROFILE_INCOMPLETE_RESPONSE);
        }
        const request = yield prisma.chainRequest.create({
            data: { batchId, status: "REQUESTED" }
        });
        const prov = yield recordOnBlockchain(batchId, "COLLECTION_REQUESTED", actorUser.id, request);
        res.json({ request, prov });
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 3. Process Batch ──
app.post('/api/processing', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { batchId, processorId, quantityReceived, quantityAfter, method, notes } = req.body;
    try {
        const batch = yield prisma.batch.findUnique({ where: { id: batchId } });
        if (!batch || batch.status !== "HARVESTED") {
            return res.status(400).json({ error: "Invalid state transition. Batch must be HARVESTED." });
        }
        const actorUser = yield ensureUserExists(processorId || 'Processor', 'COLLECTION_PROCESSING');
        if (!(0, profileService_1.isUserProfileComplete)(actorUser)) {
            return res.status(403).json(profileService_1.PROFILE_INCOMPLETE_RESPONSE);
        }
        const record = yield prisma.processingRecord.create({
            data: {
                batchId,
                processorId: actorUser.id,
                quantityReceived: Number(quantityReceived) || 0.0,
                quantityAfter: Number(quantityAfter) || 0.0,
                method: method || 'Standard Cold Extraction',
                notes: notes || ''
            }
        });
        yield prisma.batch.update({ where: { id: batchId }, data: { status: "PROCESSING_COMPLETED" } });
        const prov = yield recordOnBlockchain(batchId, "PROCESSING_COMPLETED", actorUser.id, record);
        res.json({ record, prov });
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 4. Lab Report ──
app.post('/api/lab-reports', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { batchId, labId, testResults, qualityScore, moistureContent, purityGrade, notes } = req.body;
    try {
        const actorUser = yield ensureUserExists(labId || 'Lab Officer', 'LAB_TESTING');
        if (!(0, profileService_1.isUserProfileComplete)(actorUser)) {
            return res.status(403).json(profileService_1.PROFILE_INCOMPLETE_RESPONSE);
        }
        const report = yield prisma.labReport.create({
            data: {
                batchId,
                labId: actorUser.id,
                testResults: testResults || 'Purity Grade: Grade A (99.2%), Moisture: 17.2%, Contaminants: None',
                qualityScore: qualityScore !== undefined ? Number(qualityScore) : 98.5,
                moistureContent: moistureContent !== undefined ? Number(moistureContent) : 17.2,
                purityGrade: purityGrade || 'Grade A',
                contaminantsFound: 'None',
                notes: notes || '',
                status: "APPROVED"
            }
        });
        yield prisma.batch.update({ where: { id: batchId }, data: { status: "LAB_APPROVED" } });
        const prov = yield recordOnBlockchain(batchId, "LAB_APPROVED", actorUser.id, report);
        res.json({ report, prov });
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 5. Packaging ──
app.post('/api/packaging', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { batchId, packagerId, finalQuantity, numberOfPackages, notes } = req.body;
    try {
        const batch = yield prisma.batch.findUnique({ where: { id: batchId } });
        if (!batch || batch.status !== "LAB_APPROVED") {
            return res.status(400).json({ error: "Invalid state. Packaging requires LAB_APPROVED." });
        }
        const actorUser = yield ensureUserExists(packagerId || 'Packager', 'PACKAGING');
        if (!(0, profileService_1.isUserProfileComplete)(actorUser)) {
            return res.status(403).json(profileService_1.PROFILE_INCOMPLETE_RESPONSE);
        }
        const record = yield prisma.packagingRecord.create({
            data: {
                batchId,
                packagerId: actorUser.id,
                finalQuantity: Number(finalQuantity) || 0.0,
                numberOfPackages: Number(numberOfPackages) || 1,
                notes: notes || ''
            }
        });
        yield prisma.batch.update({ where: { id: batchId }, data: { status: "PACKAGED" } });
        const prov = yield recordOnBlockchain(batchId, "PACKAGING_COMPLETED", actorUser.id, record);
        res.json({ record, prov });
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 6. View All Batches ──
app.get('/api/batches', (_req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const batches = yield prisma.batch.findMany({
            include: {
                harvest: {
                    include: {
                        harvester: true,
                        hive: true
                    }
                },
                chainRequests: true,
                processingRecords: {
                    include: { processor: true }
                },
                labReports: {
                    include: { lab: true }
                },
                packagingRecords: {
                    include: { packager: true }
                },
                provenanceEvents: {
                    orderBy: { timestamp: 'desc' }
                }
            },
            orderBy: { createdAt: 'desc' }
        });
        res.json(batches);
    }
    catch (error) {
        res.status(500).json({ error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 7. Direct Public Harvester Verification Endpoint ──
app.get('/api/verify/harvester/:verificationId', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const verificationId = String(req.params.verificationId);
        const result = yield verificationService_1.verificationService.getPublicVerificationByVerificationId(verificationId);
        if (!result.found) {
            return res.status(404).json(Object.assign({ success: false }, result));
        }
        res.json(Object.assign({ success: true }, result));
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
// ── 8. Public Batch Verification Endpoint (for QR Scanning) ──
app.get(['/api/verify', '/api/verify/:batchId', '/verify/:batchId'], (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, _20, _21, _22, _23, _24, _25, _26, _27, _28, _29, _30, _31, _32, _33, _34, _35, _36, _37, _38;
    try {
        const batchId = String(req.params.batchId || req.query.batch || req.query.traceabilityId || req.query.id || '');
        if (!batchId) {
            return res.status(400).json({ success: false, message: 'Batch / Traceability ID is required' });
        }
        const batch = yield prisma.batch.findFirst({
            where: {
                OR: [
                    { id: batchId },
                    { labReports: { some: { qrTraceabilityId: batchId } } },
                    { workflowRequests: { some: { requestId: batchId } } }
                ]
            },
            include: {
                harvest: {
                    include: {
                        harvester: { include: { harvesterVerification: true } },
                        hive: true
                    }
                },
                workflowRequests: {
                    include: { fromUser: true, toUser: true },
                    orderBy: { createdAt: 'asc' }
                },
                processingRecords: { include: { processor: true } },
                labReports: { include: { lab: true } },
                packagingRecords: { include: { packager: true } },
                provenanceEvents: { orderBy: { timestamp: 'asc' } }
            }
        });
        if (!batch) {
            return res.status(404).json({
                success: false,
                found: false,
                message: `Batch ${batchId} not found on HoneyChain Provenance Ledger.`
            });
        }
        const verifiedLab = batch.labReports.find((r) => r.status === 'APPROVED' || r.overallResult === 'PASS') || batch.labReports[0] || null;
        const latestPackaging = batch.packagingRecords[0] || null;
        const latestProcessing = batch.processingRecords[0] || null;
        res.json({
            success: true,
            found: true,
            batchId: batch.id,
            traceabilityId: batch.id,
            status: batch.status,
            currentStage: batch.currentStage,
            isFullyVerified: batch.status === 'COMPLETED' || batch.currentStage === 'COMPLETED',
            createdAt: batch.createdAt,
            product: {
                productName: `${((_b = (_a = batch.harvest) === null || _a === void 0 ? void 0 : _a.hive) === null || _b === void 0 ? void 0 : _b.honeyType) || 'Raw Wildflower'} Honey`,
                batchId: batch.id,
                traceabilityId: batch.id,
                quantityKg: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.finalQuantity) || ((_c = batch.harvest) === null || _c === void 0 ? void 0 : _c.quantity) || 0,
                numberOfPackages: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.numberOfPackages) || 0,
                packageSize: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.packageSize) || '500g Glass Jar (Tamper-Evident)',
                packagingDate: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.createdAt) || batch.updatedAt,
                status: batch.status === 'COMPLETED' ? 'VERIFIED GENUINE HONEY' : batch.status
            },
            harvester: {
                name: ((_e = (_d = batch.harvest) === null || _d === void 0 ? void 0 : _d.harvester) === null || _e === void 0 ? void 0 : _e.name) || 'Verified Harvester',
                email: (_g = (_f = batch.harvest) === null || _f === void 0 ? void 0 : _f.harvester) === null || _g === void 0 ? void 0 : _g.email,
                beekeeperId: ((_j = (_h = batch.harvest) === null || _h === void 0 ? void 0 : _h.harvester) === null || _j === void 0 ? void 0 : _j.beekeeperId) || ((_l = (_k = batch.harvest) === null || _k === void 0 ? void 0 : _k.harvester) === null || _l === void 0 ? void 0 : _l.bsid) || 'HC-BK-97FD3395',
                verificationStatus: ((_p = (_o = (_m = batch.harvest) === null || _m === void 0 ? void 0 : _m.harvester) === null || _o === void 0 ? void 0 : _o.harvesterVerification) === null || _p === void 0 ? void 0 : _p.verificationStatus) || 'Verified',
                location: ((_q = batch.harvest) === null || _q === void 0 ? void 0 : _q.location) || ((_s = (_r = batch.harvest) === null || _r === void 0 ? void 0 : _r.hive) === null || _s === void 0 ? void 0 : _s.apiaryLocation) || 'Cascade Valley, OR',
                hiveId: ((_u = (_t = batch.harvest) === null || _t === void 0 ? void 0 : _t.hive) === null || _u === void 0 ? void 0 : _u.id) || 'N/A',
                hiveCode: ((_w = (_v = batch.harvest) === null || _v === void 0 ? void 0 : _v.hive) === null || _w === void 0 ? void 0 : _w.hiveCode) || 'N/A',
                hiveName: ((_y = (_x = batch.harvest) === null || _x === void 0 ? void 0 : _x.hive) === null || _y === void 0 ? void 0 : _y.name) || 'Primary Hive',
                hiveType: ((_0 = (_z = batch.harvest) === null || _z === void 0 ? void 0 : _z.hive) === null || _0 === void 0 ? void 0 : _0.hiveType) || 'Langstroth',
                queenStatus: ((_2 = (_1 = batch.harvest) === null || _1 === void 0 ? void 0 : _1.hive) === null || _2 === void 0 ? void 0 : _2.queenStatus) || 'Mated & Active',
                beeBreed: ((_4 = (_3 = batch.harvest) === null || _3 === void 0 ? void 0 : _3.hive) === null || _4 === void 0 ? void 0 : _4.beeBreed) || 'Italian (Apis mellifera ligustica)',
                honeyType: ((_6 = (_5 = batch.harvest) === null || _5 === void 0 ? void 0 : _5.hive) === null || _6 === void 0 ? void 0 : _6.honeyType) || 'Wildflower',
                quantityKg: ((_7 = batch.harvest) === null || _7 === void 0 ? void 0 : _7.quantity) || 0,
                harvestDate: ((_8 = batch.harvest) === null || _8 === void 0 ? void 0 : _8.createdAt) || batch.createdAt
            },
            collectionProcessing: latestProcessing ? {
                processor: ((_9 = latestProcessing.processor) === null || _9 === void 0 ? void 0 : _9.name) || 'Authorized Processing Center',
                organizationName: ((_10 = latestProcessing.processor) === null || _10 === void 0 ? void 0 : _10.organizationName) || ((_11 = latestProcessing.processor) === null || _11 === void 0 ? void 0 : _11.name),
                location: ((_12 = latestProcessing.processor) === null || _12 === void 0 ? void 0 : _12.facilityLocation) || 'Bend Industrial Center, OR',
                method: latestProcessing.method || 'Standard Cold Extraction & Centrifugation',
                quantityReceived: latestProcessing.quantityReceived,
                quantityAfter: latestProcessing.quantityAfter,
                moistureAtReceipt: latestProcessing.moistureAtReceipt || 17.0,
                notes: latestProcessing.notes,
                status: 'ACCEPTED & PROCESSED',
                processedAt: latestProcessing.createdAt
            } : null,
            labVerification: verifiedLab ? {
                labName: verifiedLab.labName || ((_13 = verifiedLab.lab) === null || _13 === void 0 ? void 0 : _13.name) || 'Pacific Pure Apiculture Analytical Labs',
                labAddress: ((_14 = verifiedLab.lab) === null || _14 === void 0 ? void 0 : _14.facilityLocation) || 'Corvallis Tech Campus, OR',
                testerName: verifiedLab.labTesterName || ((_15 = verifiedLab.lab) === null || _15 === void 0 ? void 0 : _15.name) || 'Chief Analytical Chemist',
                sampleId: verifiedLab.sampleCode || `SMP-${batch.id.slice(-6)}`,
                reportId: verifiedLab.reportId || `LAB-RPT-2026-${batch.id.slice(-6)}`,
                qualityScore: verifiedLab.qualityScore || 96.5,
                status: verifiedLab.status || 'APPROVED',
                overallResult: verifiedLab.overallResult || 'PASS',
                testDate: verifiedLab.testDate || verifiedLab.createdAt,
                parameters: [
                    {
                        name: 'Moisture Content',
                        value: `${verifiedLab.moistureValue || verifiedLab.moistureContent || 16.8}%`,
                        limit: verifiedLab.moistureLimit || '<= 20.0%',
                        unit: '%',
                        status: verifiedLab.moistureStatus || 'PASS'
                    },
                    {
                        name: 'Hydroxymethylfurfural (HMF)',
                        value: `${verifiedLab.hmfValue || 12.4} mg/kg`,
                        limit: verifiedLab.hmfLimit || '<= 40.0 mg/kg',
                        unit: 'mg/kg',
                        status: verifiedLab.hmfStatus || 'PASS'
                    },
                    {
                        name: 'Diastase Activity',
                        value: `${verifiedLab.diastaseValue || 14.2} Schade Units`,
                        limit: verifiedLab.diastaseLimit || '>= 8.0 Schade Units',
                        unit: 'Schade Units',
                        status: verifiedLab.diastaseStatus || 'PASS'
                    },
                    {
                        name: 'F/G Purity Ratio (Fructose/Glucose)',
                        value: `${verifiedLab.purityValue || 1.15}`,
                        limit: verifiedLab.purityLimit || '>= 0.95 F/G Ratio',
                        unit: 'Ratio',
                        status: verifiedLab.purityStatus || 'PASS'
                    },
                    {
                        name: 'Antibiotic & Chemical Residues',
                        value: verifiedLab.residuesValue || 'None Detected (< 0.01 ppm)',
                        limit: verifiedLab.residuesLimit || '0.0 ppm (None Detected)',
                        unit: 'ppm',
                        status: verifiedLab.residuesStatus || 'PASS'
                    },
                    {
                        name: 'Microscopic Pollen Origin Analysis',
                        value: verifiedLab.pollenValue || 'Authentic Floral Matrix (Apis mellifera)',
                        limit: verifiedLab.pollenLimit || 'Botanical Origin Authentic',
                        unit: 'Morphology',
                        status: verifiedLab.pollenStatus || 'PASS'
                    }
                ],
                remarks: verifiedLab.remarks || 'All physicochemical and spectrometry parameters conform strictly to FSSAI & Codex Alimentarius Honey Standards.'
            } : null,
            packaging: latestPackaging ? {
                packager: ((_16 = latestPackaging.packager) === null || _16 === void 0 ? void 0 : _16.name) || 'Artisan Honey Bottling & Cleanroom Packaging Co.',
                facilityLocation: ((_17 = latestPackaging.packager) === null || _17 === void 0 ? void 0 : _17.facilityLocation) || 'Portland Logistics Hub, OR',
                packagingId: latestPackaging.id,
                batchId: latestPackaging.batchId,
                finalQuantityKg: latestPackaging.finalQuantity,
                numberOfPackages: latestPackaging.numberOfPackages,
                packageSize: latestPackaging.packageSize || '500g Glass Jar',
                sealType: 'Induction Tamper-Evident Seal with Batch QR',
                qrCodeUrl: latestPackaging.qrCodeUrl,
                status: 'SEALED & VERIFIED',
                packagedAt: latestPackaging.createdAt
            } : null,
            timeline: [
                {
                    stage: 'HIVE_CREATED',
                    title: '🌱 Hive Created & Registered',
                    date: ((_19 = (_18 = batch.harvest) === null || _18 === void 0 ? void 0 : _18.hive) === null || _19 === void 0 ? void 0 : _19.dateAdded) || ((_20 = batch.harvest) === null || _20 === void 0 ? void 0 : _20.createdAt) || batch.createdAt,
                    actor: ((_22 = (_21 = batch.harvest) === null || _21 === void 0 ? void 0 : _21.harvester) === null || _22 === void 0 ? void 0 : _22.name) || 'Harvester',
                    details: `Hive: ${((_24 = (_23 = batch.harvest) === null || _23 === void 0 ? void 0 : _23.hive) === null || _24 === void 0 ? void 0 : _24.name) || 'Primary Hive'} (${((_26 = (_25 = batch.harvest) === null || _25 === void 0 ? void 0 : _25.hive) === null || _26 === void 0 ? void 0 : _26.hiveCode) || 'HC-HIVE'}) at ${((_28 = (_27 = batch.harvest) === null || _27 === void 0 ? void 0 : _27.hive) === null || _28 === void 0 ? void 0 : _28.apiaryLocation) || 'Apiary'}`
                },
                {
                    stage: 'HONEY_HARVESTED',
                    title: '🍯 Honey Harvested',
                    date: ((_29 = batch.harvest) === null || _29 === void 0 ? void 0 : _29.createdAt) || batch.createdAt,
                    actor: ((_31 = (_30 = batch.harvest) === null || _30 === void 0 ? void 0 : _30.harvester) === null || _31 === void 0 ? void 0 : _31.name) || 'Harvester',
                    details: `${((_32 = batch.harvest) === null || _32 === void 0 ? void 0 : _32.quantity) || 0} kg raw honey extracted by ${((_34 = (_33 = batch.harvest) === null || _33 === void 0 ? void 0 : _33.harvester) === null || _34 === void 0 ? void 0 : _34.name) || 'Harvester'}`
                },
                {
                    stage: 'COLLECTED_PROCESSED',
                    title: '🏭 Collected & Processed',
                    date: (latestProcessing === null || latestProcessing === void 0 ? void 0 : latestProcessing.createdAt) || null,
                    actor: ((_35 = latestProcessing === null || latestProcessing === void 0 ? void 0 : latestProcessing.processor) === null || _35 === void 0 ? void 0 : _35.name) || 'Collection & Processing Center',
                    details: latestProcessing ? `${latestProcessing.method} (${latestProcessing.quantityAfter} kg output)` : 'Pending processing'
                },
                {
                    stage: 'LAB_TESTED',
                    title: '🧪 Lab Tested & Quality Certified',
                    date: (verifiedLab === null || verifiedLab === void 0 ? void 0 : verifiedLab.testDate) || (verifiedLab === null || verifiedLab === void 0 ? void 0 : verifiedLab.createdAt) || null,
                    actor: (verifiedLab === null || verifiedLab === void 0 ? void 0 : verifiedLab.labName) || ((_36 = verifiedLab === null || verifiedLab === void 0 ? void 0 : verifiedLab.lab) === null || _36 === void 0 ? void 0 : _36.name) || 'Certified Analytical Laboratory',
                    details: verifiedLab ? `Score: ${verifiedLab.qualityScore}/100 • Moisture: ${verifiedLab.moistureContent}% • Result: PASS` : 'Pending lab test'
                },
                {
                    stage: 'PACKAGED',
                    title: '📦 Packaged & Sealed',
                    date: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.createdAt) || null,
                    actor: ((_37 = latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.packager) === null || _37 === void 0 ? void 0 : _37.name) || 'Packaging Center',
                    details: latestPackaging ? `${latestPackaging.numberOfPackages} units (${latestPackaging.packageSize}) sealed` : 'Pending packaging'
                },
                {
                    stage: 'VERIFIED_PRODUCT',
                    title: '✓ Verified Product on Blockchain',
                    date: (latestPackaging === null || latestPackaging === void 0 ? void 0 : latestPackaging.createdAt) || batch.updatedAt,
                    actor: 'HoneyChain Provenance Ledger',
                    details: batch.status === 'COMPLETED' ? '100% Provenance Authenticated & Digitally Sealed' : 'Workflow in Progress'
                }
            ],
            provenanceEvents: batch.provenanceEvents,
            blockchainVerification: {
                totalConfirmedEvents: batch.provenanceEvents.filter((e) => e.status === 'CONFIRMED').length,
                network: 'Hardhat Localhost (Chain ID: 31337)',
                ledgerStatus: batch.provenanceEvents.some((e) => e.status === 'CONFIRMED') ? 'LEDGER_VERIFIED' : 'PENDING_CONFIRMATION',
                latestTxHash: ((_38 = batch.provenanceEvents.find((e) => e.txHash)) === null || _38 === void 0 ? void 0 : _38.txHash) || null
            }
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
const port = Number(process.env.PORT) || 3000;
app.listen(port, '0.0.0.0', () => {
    console.log(`🐝 HoneyChain Backend running on http://127.0.0.1:${port} and http://localhost:${port}`);
    console.log(`📱 Mobile OTP & Verification API accessible at /api/verification`);
});
