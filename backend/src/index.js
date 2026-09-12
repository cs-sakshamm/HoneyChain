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
const verificationRoutes_1 = __importDefault(require("./routes/verificationRoutes"));
const verificationService_1 = require("./services/verificationService");
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
const prisma = new client_1.PrismaClient();
// Blockchain configuration
const PRIVATE_KEY = process.env.BLOCKCHAIN_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Account 0 on Hardhat Localhost
const PROVIDER_URL = process.env.BLOCKCHAIN_PROVIDER_URL || 'http://127.0.0.1:8545';
const contractAddress = process.env.CONTRACT_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const provider = new ethers_1.ethers.JsonRpcProvider(PROVIDER_URL);
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
            }
        });
        if (!user) {
            const safeId = userIdOrName.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
            user = yield prisma.user.create({
                data: {
                    name: userIdOrName,
                    email: `${safeId}@honeychain.io`,
                    role: defaultRole
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
app.use('/api/verification', verificationRoutes_1.default);
// ── 1. Create Harvest & Batch ──
app.post('/api/harvests', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { harvesterId, hiveId, quantity, location, notes } = req.body;
    try {
        const actorUser = yield ensureUserExists(harvesterId || 'Harvester', 'HARVESTER');
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
app.get('/api/verify', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c, _d;
    try {
        const batchId = String(req.query.batch || '');
        if (!batchId) {
            return res.status(400).json({ success: false, message: 'Batch ID is required' });
        }
        const batch = yield prisma.batch.findUnique({
            where: { id: batchId },
            include: {
                harvest: {
                    include: { harvester: true, hive: true }
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
        res.json({
            success: true,
            found: true,
            batchId: batch.id,
            status: batch.status,
            harvester: ((_b = (_a = batch.harvest) === null || _a === void 0 ? void 0 : _a.harvester) === null || _b === void 0 ? void 0 : _b.name) || 'Verified Harvester',
            location: ((_c = batch.harvest) === null || _c === void 0 ? void 0 : _c.location) || 'Cascade Valley, OR',
            quantityKg: (_d = batch.harvest) === null || _d === void 0 ? void 0 : _d.quantity,
            createdAt: batch.createdAt,
            labReport: batch.labReports[0] || null,
            packaging: batch.packagingRecords[0] || null,
            events: batch.provenanceEvents
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
const port = process.env.PORT || 3000;
app.listen(port, () => {
    console.log(`🐝 HoneyChain PostgreSQL Backend running on port ${port}`);
});
