import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import { ethers } from 'ethers';
import * as crypto from 'crypto';

import authRoutes from './routes/authRoutes';
import hiveRoutes from './routes/hiveRoutes';
import verificationRoutes from './routes/verificationRoutes';
import workflowRoutes from './routes/workflowRoutes';
import { verificationService } from './services/verificationService';
import { isUserProfileComplete, PROFILE_INCOMPLETE_RESPONSE } from './services/profileService';

const app = express();
app.use(cors());
app.use(express.json());

const prisma = new PrismaClient();

// Blockchain configuration
const PRIVATE_KEY = process.env.BLOCKCHAIN_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Account 0 on Hardhat Localhost
const PROVIDER_URL = process.env.BLOCKCHAIN_PROVIDER_URL || 'http://127.0.0.1:8545';
const contractAddress = process.env.CONTRACT_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const provider = new ethers.JsonRpcProvider(PROVIDER_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const contractAbi = [
  "function recordEvent(string memory batchId, string memory eventType, string memory actorId, string memory dataHash, string memory previousEventHash) public",
  "event ProvenanceRecorded(string indexed batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)"
];
const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

// Helper function to record event on blockchain
async function recordOnBlockchain(batchId: string, eventType: string, actorId: string, dataObj: any) {
  const dataString = JSON.stringify(dataObj);
  const dataHash = crypto.createHash('sha256').update(dataString).digest('hex');
  
  // Create pending event in DB
  let provEvent = await prisma.provenanceEvent.create({
    data: {
      batchId,
      eventType,
      actorId,
      dataHash,
      status: 'PENDING'
    }
  });

  try {
    const tx = await (contract as any).recordEvent(batchId, eventType, actorId, dataHash, "");
    const receipt = await tx.wait();
    
    // Update DB with success
    provEvent = await prisma.provenanceEvent.update({
      where: { id: provEvent.id },
      data: {
        txHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        status: 'CONFIRMED'
      }
    });
  } catch (error) {
    console.warn("[Blockchain] Transaction not committed on chain (node might be offline):", (error as any)?.message || error);
    provEvent = await prisma.provenanceEvent.update({
      where: { id: provEvent.id },
      data: { status: 'FAILED' }
    });
  }
  return provEvent;
}

// Ensure actor user exists in PostgreSQL to satisfy foreign key constraints
async function ensureUserExists(userIdOrName: string, defaultRole: string = 'HARVESTER') {
  let user = await prisma.user.findFirst({
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
    user = await prisma.user.create({
      data: {
        name: userIdOrName,
        email: `${safeId}@honeychain.io`,
        role: defaultRole
      }
    });
  }
  return user;
}

// ── Health Check (PostgreSQL Status) ──
app.get('/api/health', async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({
      status: 'healthy',
      database: 'PostgreSQL connected',
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'PostgreSQL connection failed',
      error: error?.message || String(error)
    });
  }
});

// ── Mount Modular Routes ──
app.use('/api/auth', authRoutes);
app.use('/api', authRoutes); // Exposes /api/profile and /api/profile/identity
app.use('/api/hives', hiveRoutes);
app.use('/api/verification', verificationRoutes);
app.use('/api', workflowRoutes); // Exposes /api/requests, /api/batches, /api/lab-reports, /api/packaging

// ── 1. Create Harvest & Batch ──
app.post('/api/harvests', async (req, res) => {
  const { harvesterId, hiveId, quantity, location, notes } = req.body;
  try {
    const actorUser = await ensureUserExists(harvesterId || 'Harvester', 'HARVESTER');
    if (!isUserProfileComplete(actorUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    const harvest = await prisma.harvest.create({
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
    const batch = await prisma.batch.create({
      data: { id: batchId, harvestId: harvest.id, status: "HARVESTED" }
    });

    const prov = await recordOnBlockchain(batchId, "HARVEST_CREATED", actorUser.id, harvest);
    res.json({ harvest, batch, prov });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 2. Create Chain Request ──
app.post('/api/chain-requests', async (req, res) => {
  const { batchId, requesterId } = req.body;
  try {
    const actorUser = await ensureUserExists(requesterId || 'Requester', 'COLLECTION_PROCESSING');
    if (!isUserProfileComplete(actorUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    const request = await prisma.chainRequest.create({
      data: { batchId, status: "REQUESTED" }
    });
    const prov = await recordOnBlockchain(batchId, "COLLECTION_REQUESTED", actorUser.id, request);
    res.json({ request, prov });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 3. Process Batch ──
app.post('/api/processing', async (req, res) => {
  const { batchId, processorId, quantityReceived, quantityAfter, method, notes } = req.body;
  try {
    const batch = await prisma.batch.findUnique({ where: { id: batchId } });
    if (!batch || batch.status !== "HARVESTED") {
      return res.status(400).json({ error: "Invalid state transition. Batch must be HARVESTED." });
    }

    const actorUser = await ensureUserExists(processorId || 'Processor', 'COLLECTION_PROCESSING');
    if (!isUserProfileComplete(actorUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    const record = await prisma.processingRecord.create({
      data: {
        batchId,
        processorId: actorUser.id,
        quantityReceived: Number(quantityReceived) || 0.0,
        quantityAfter: Number(quantityAfter) || 0.0,
        method: method || 'Standard Cold Extraction',
        notes: notes || ''
      }
    });
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "PROCESSING_COMPLETED" }});
    const prov = await recordOnBlockchain(batchId, "PROCESSING_COMPLETED", actorUser.id, record);
    
    res.json({ record, prov });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 4. Lab Report ──
app.post('/api/lab-reports', async (req, res) => {
  const { batchId, labId, testResults, qualityScore, moistureContent, purityGrade, notes } = req.body;
  try {
    const actorUser = await ensureUserExists(labId || 'Lab Officer', 'LAB_TESTING');
    if (!isUserProfileComplete(actorUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    const report = await prisma.labReport.create({
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
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "LAB_APPROVED" }});
    const prov = await recordOnBlockchain(batchId, "LAB_APPROVED", actorUser.id, report);
    
    res.json({ report, prov });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 5. Packaging ──
app.post('/api/packaging', async (req, res) => {
  const { batchId, packagerId, finalQuantity, numberOfPackages, notes } = req.body;
  try {
    const batch = await prisma.batch.findUnique({ where: { id: batchId } });
    if (!batch || batch.status !== "LAB_APPROVED") {
      return res.status(400).json({ error: "Invalid state. Packaging requires LAB_APPROVED." });
    }

    const actorUser = await ensureUserExists(packagerId || 'Packager', 'PACKAGING');
    if (!isUserProfileComplete(actorUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    const record = await prisma.packagingRecord.create({
      data: {
        batchId,
        packagerId: actorUser.id,
        finalQuantity: Number(finalQuantity) || 0.0,
        numberOfPackages: Number(numberOfPackages) || 1,
        notes: notes || ''
      }
    });
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "PACKAGED" }});
    const prov = await recordOnBlockchain(batchId, "PACKAGING_COMPLETED", actorUser.id, record);
    
    res.json({ record, prov });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 6. View All Batches ──
app.get('/api/batches', async (_req, res) => {
  try {
    const batches = await prisma.batch.findMany({
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
  } catch (error: any) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// ── 7. Direct Public Harvester Verification Endpoint ──
app.get('/api/verify/harvester/:verificationId', async (req, res) => {
  try {
    const verificationId = String(req.params.verificationId);
    const result = await verificationService.getPublicVerificationByVerificationId(verificationId);
    if (!result.found) {
      return res.status(404).json({ success: false, ...result });
    }
    res.json({ success: true, ...result });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

// ── 8. Public Batch Verification Endpoint (for QR Scanning) ──
app.get('/api/verify', async (req, res) => {
  try {
    const batchId = String(req.query.batch || '');
    if (!batchId) {
      return res.status(400).json({ success: false, message: 'Batch ID is required' });
    }

    const batch = await prisma.batch.findUnique({
      where: { id: batchId },
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

    const verifiedLab = batch.labReports.find((r) => r.status === 'APPROVED') || batch.labReports[0] || null;
    const latestPackaging = batch.packagingRecords[0] || null;
    const latestProcessing = batch.processingRecords[0] || null;

    res.json({
      success: true,
      found: true,
      batchId: batch.id,
      status: batch.status,
      currentStage: batch.currentStage,
      createdAt: batch.createdAt,
      harvester: {
        name: batch.harvest?.harvester?.name || 'Verified Harvester',
        email: batch.harvest?.harvester?.email,
        bsid: batch.harvest?.harvester?.bsid || null,
        verificationStatus: batch.harvest?.harvester?.harvesterVerification?.verificationStatus || 'Verified',
        location: batch.harvest?.location || 'Cascade Valley, OR',
        hiveCode: batch.harvest?.hive?.hiveCode || 'HC-HIVE-01',
        honeyType: batch.harvest?.hive?.honeyType || 'Wildflower',
        quantityKg: batch.harvest?.quantity || 0,
        harvestDate: batch.harvest?.createdAt || batch.createdAt
      },
      collectionProcessing: latestProcessing ? {
        processor: latestProcessing.processor?.name || 'Authorized Processing Center',
        method: latestProcessing.method,
        quantityReceived: latestProcessing.quantityReceived,
        quantityAfter: latestProcessing.quantityAfter,
        notes: latestProcessing.notes,
        processedAt: latestProcessing.createdAt
      } : null,
      labVerification: verifiedLab ? {
        labName: verifiedLab.lab?.name || 'Certified Honey Quality Testing Lab',
        qualityScore: verifiedLab.qualityScore,
        moistureContent: verifiedLab.moistureContent,
        purityGrade: verifiedLab.purityGrade,
        contaminantsFound: verifiedLab.contaminantsFound,
        status: verifiedLab.status,
        verifiedAt: verifiedLab.createdAt
      } : null,
      packaging: latestPackaging ? {
        packager: latestPackaging.packager?.name || 'HoneyChain Packaging Facility',
        finalQuantityKg: latestPackaging.finalQuantity,
        numberOfPackages: latestPackaging.numberOfPackages,
        packageSize: latestPackaging.packageSize,
        qrCodeUrl: latestPackaging.qrCodeUrl,
        packagedAt: latestPackaging.createdAt
      } : null,
      provenanceEvents: batch.provenanceEvents,
      blockchainVerification: {
        totalConfirmedEvents: batch.provenanceEvents.filter((e) => e.status === 'CONFIRMED').length,
        network: 'Hardhat Localhost (Chain ID: 31337)',
        ledgerStatus: batch.provenanceEvents.some((e) => e.status === 'CONFIRMED') ? 'LEDGER_VERIFIED' : 'PENDING_CONFIRMATION',
        latestTxHash: batch.provenanceEvents.find((e) => e.txHash)?.txHash || null
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`🐝 HoneyChain PostgreSQL Backend running on port ${port}`);
});
