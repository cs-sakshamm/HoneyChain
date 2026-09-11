import express from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import { ethers } from 'ethers';
import * as crypto from 'crypto';

const app = express();
app.use(cors());
app.use(express.json());

const prisma = new PrismaClient();

// Blockchain configuration
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Account 0 on Hardhat Localhost
const PROVIDER_URL = 'http://127.0.0.1:8545';
const provider = new ethers.JsonRpcProvider(PROVIDER_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const contractAbi = [
  "function recordEvent(string memory batchId, string memory eventType, string memory actorId, string memory dataHash, string memory previousEventHash) public",
  "event ProvenanceRecorded(string indexed batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)"
];
// Wait for contract deploy step to fill this, or just hardcode the typical first deploy address
const contractAddress = process.env.CONTRACT_ADDRESS || "0x5FbDB2315678afecb367f032d93F642f64180aa3";
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
    console.error("Blockchain error:", error);
    provEvent = await prisma.provenanceEvent.update({
      where: { id: provEvent.id },
      data: { status: 'FAILED' }
    });
  }
  return provEvent;
}

// 1. Create Harvest
app.post('/api/harvests', async (req, res) => {
  const { harvesterId, hiveId, quantity, location, notes } = req.body;
  try {
    const harvest = await prisma.harvest.create({
      data: { harvesterId, hiveId, quantity, location, notes, status: "HARVESTED" }
    });
    
    const batchId = `HC-BATCH-2026-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const batch = await prisma.batch.create({
      data: { id: batchId, harvestId: harvest.id, status: "HARVESTED" }
    });

    const prov = await recordOnBlockchain(batchId, "HARVEST_CREATED", harvesterId, harvest);
    res.json({ harvest, batch, prov });
  } catch (error) {
    res.status(500).json({ error: String(error) });
  }
});

// 2. Create Chain Request
app.post('/api/chain-requests', async (req, res) => {
  const { batchId, requesterId } = req.body;
  try {
    const request = await prisma.chainRequest.create({
      data: { batchId, status: "REQUESTED" }
    });
    const prov = await recordOnBlockchain(batchId, "COLLECTION_REQUESTED", requesterId, request);
    res.json({ request, prov });
  } catch (error) {
    res.status(500).json({ error: String(error) });
  }
});

// 3. Process Batch
app.post('/api/processing', async (req, res) => {
  const { batchId, processorId, quantityReceived, quantityAfter, method, notes } = req.body;
  try {
    // State machine check
    const batch = await prisma.batch.findUnique({ where: { id: batchId } });
    if (!batch || batch.status !== "HARVESTED") {
      return res.status(400).json({ error: "Invalid state transition. Batch must be HARVESTED." });
    }

    const record = await prisma.processingRecord.create({
      data: { batchId, processorId, quantityReceived, quantityAfter, method, notes }
    });
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "PROCESSING_COMPLETED" }});
    const prov = await recordOnBlockchain(batchId, "PROCESSING_COMPLETED", processorId, record);
    
    res.json({ record, prov });
  } catch (error) {
    res.status(500).json({ error: String(error) });
  }
});

// 4. Lab Report
app.post('/api/lab-reports', async (req, res) => {
  const { batchId, labId, testResults, qualityScore, notes } = req.body;
  try {
    const report = await prisma.labReport.create({
      data: { batchId, labId, testResults, qualityScore, notes, status: "APPROVED" }
    });
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "LAB_APPROVED" }});
    const prov = await recordOnBlockchain(batchId, "LAB_APPROVED", labId, report);
    
    res.json({ report, prov });
  } catch (error) {
    res.status(500).json({ error: String(error) });
  }
});

// 5. Packaging
app.post('/api/packaging', async (req, res) => {
  const { batchId, packagerId, finalQuantity, numberOfPackages, notes } = req.body;
  try {
    const batch = await prisma.batch.findUnique({ where: { id: batchId } });
    if (!batch || batch.status !== "LAB_APPROVED") {
      return res.status(400).json({ error: "Invalid state. Packaging requires LAB_APPROVED." });
    }

    const record = await prisma.packagingRecord.create({
      data: { batchId, packagerId, finalQuantity, numberOfPackages, notes }
    });
    
    await prisma.batch.update({ where: { id: batchId }, data: { status: "PACKAGED" }});
    const prov = await recordOnBlockchain(batchId, "PACKAGING_COMPLETED", packagerId, record);
    
    res.json({ record, prov });
  } catch (error) {
    res.status(500).json({ error: String(error) });
  }
});

// View all batches
app.get('/api/batches', async (req, res) => {
  const batches = await prisma.batch.findMany({
    include: {
      harvest: true,
      chainRequests: true,
      processingRecords: true,
      labReports: true,
      packagingRecords: true,
      provenanceEvents: true
    }
  });
  res.json(batches);
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
