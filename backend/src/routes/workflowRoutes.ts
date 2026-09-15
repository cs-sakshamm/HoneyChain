import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { blockchainService } from '../services/blockchainService';

const router = Router();
const prisma = new PrismaClient();

import {
  isUserProfileComplete,
  normalizeUserRole,
  isHarvesterFullyVerified,
  isCollectorFullyVerified,
  isLabTesterFullyVerified,
  isPackagingManagerFullyVerified,
  PROFILE_INCOMPLETE_RESPONSE,
  HARVESTER_VERIFICATION_REQUIRED_RESPONSE,
  COLLECTOR_VERIFICATION_REQUIRED_RESPONSE,
  LAB_VERIFICATION_REQUIRED_RESPONSE,
  PACKAGING_VERIFICATION_REQUIRED_RESPONSE
} from '../services/profileService';
import { parseCoordinates, calculateHaversineDistanceKm } from '../services/geoService';

// Helper to generate unique Request ID
function generateRequestId(stagePrefix: string): string {
  const hex = crypto.randomBytes(4).toString('hex').toUpperCase();
  return `REQ-${stagePrefix}-2026-${hex}`;
}

// Role normalization helper
function normalizeRole(role?: string): string {
  return normalizeUserRole(role);
}

// Check if user profile has required fields
function isProfileComplete(user: any): boolean {
  return isUserProfileComplete(user);
}

// Ensure actor user exists in DB
async function ensureUser(userIdOrName: string, role: string = 'HARVESTER') {
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
    const safeName = userIdOrName.trim();
    const safeId = safeName.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
    user = await prisma.user.create({
      data: {
        name: safeName,
        email: `${safeId || 'user'}@honeychain.io`,
        role: normalizeRole(role)
      }
    });
  }
  return user;
}

// Record blockchain provenance event and store in DB
async function recordWorkflowProvenance(
  batchId: string,
  eventType: string,
  actorId: string,
  requestId?: string,
  payload: any = {}
) {
  const onChainResult = await blockchainService.recordBatchEventOnChain(
    batchId,
    eventType,
    actorId,
    payload
  );

  const provEvent = await prisma.provenanceEvent.create({
    data: {
      batchId,
      requestId: requestId || null,
      eventType,
      actorId,
      dataHash: onChainResult.dataHash,
      txHash: onChainResult.txHash || null,
      blockNumber: onChainResult.blockNumber || null,
      network: onChainResult.network,
      contractAddress: blockchainService.contractAddress,
      status: onChainResult.status
    }
  });

  return { provEvent, onChainResult };
}

// The GET /verify route was removed because index.ts handles /api/verify with a comprehensive response for QR scanning.
/**
 * ─────────────────────────────────────────────────────────
 * 0. GET /api/centers/nearest
 * Find nearest verified partner centers (Collector, Lab, Packager)
 * ─────────────────────────────────────────────────────────
 */
router.get('/centers/nearest', async (req: Request, res: Response) => {
  try {
    const {
      role,
      lat,
      lng,
      originLocation,
      originHiveId,
      batchId,
      userId
    } = req.query;

    if (!role) {
      return res.status(400).json({ success: false, error: 'Target role is required (COLLECTOR_PROCESSOR, LAB, or PACKAGING)' });
    }

    const targetRole = normalizeRole(String(role));

    // Resolve Origin Coordinates
    let originCoords: { lat: number; lng: number } | null = null;
    if (lat && lng) {
      const parsedLat = parseFloat(String(lat));
      const parsedLng = parseFloat(String(lng));
      if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
        originCoords = { lat: parsedLat, lng: parsedLng };
      }
    }

    if (!originCoords && originLocation) {
      originCoords = parseCoordinates(String(originLocation));
    }

    if (!originCoords && originHiveId) {
      const hive = await prisma.hive.findUnique({ where: { id: String(originHiveId) } });
      if (hive) {
        originCoords = parseCoordinates(hive.apiaryLocation);
      }
    }

    if (!originCoords && batchId) {
      const batch = await prisma.batch.findUnique({
        where: { id: String(batchId) },
        include: {
          harvest: { include: { hive: true, harvester: { include: { harvesterVerification: true } } } },
          processingRecords: { include: { processor: true } }
        }
      });
      if (batch) {
        if (targetRole === 'PACKAGING' && batch.processingRecords[0]?.processor?.facilityLocation) {
          originCoords = parseCoordinates(batch.processingRecords[0].processor.facilityLocation);
        } else if (batch.harvest?.hive?.apiaryLocation) {
          originCoords = parseCoordinates(batch.harvest.hive.apiaryLocation);
        } else if (batch.harvest?.location) {
          originCoords = parseCoordinates(batch.harvest.location);
        } else if (batch.harvest?.harvester?.harvesterVerification?.apiaryCoordinates) {
          originCoords = parseCoordinates(batch.harvest.harvester.harvesterVerification.apiaryCoordinates);
        }
      }
    }

    if (!originCoords && userId) {
      const user = await prisma.user.findFirst({
        where: { OR: [{ id: String(userId) }, { email: String(userId) }] },
        include: { harvesterVerification: true }
      });
      if (user?.harvesterVerification?.apiaryCoordinates) {
        originCoords = parseCoordinates(user.harvesterVerification.apiaryCoordinates);
      } else if (user?.facilityLocation) {
        originCoords = parseCoordinates(user.facilityLocation);
      }
    }

    // Default origin fallback (Cascade Valley Apiary)
    if (!originCoords) {
      originCoords = { lat: 44.0521, lng: -121.3153 };
    }

    // Fetch verified users of targetRole
    const users = await prisma.user.findMany({
      where: {
        role: targetRole
      },
      include: {
        collectorVerification: true,
        labVerification: true,
        packagingVerification: true
      }
    });

    // Filter only verified centers
    const verifiedCenters = users.filter((u) => {
      if (targetRole === 'COLLECTOR_PROCESSOR') {
        return isCollectorFullyVerified(u.collectorVerification);
      }
      if (targetRole === 'LAB') {
        return isLabTesterFullyVerified(u.labVerification);
      }
      if (targetRole === 'PACKAGING') {
        return isPackagingManagerFullyVerified(u.packagingVerification);
      }
      return true;
    });

    const results = verifiedCenters.map((u) => {
      let locStr = u.facilityLocation || '';
      let specialty = '';
      let license = u.licenseNumber || '';

      if (targetRole === 'COLLECTOR_PROCESSOR') {
        locStr = u.collectorVerification?.facilityLocation || u.facilityLocation || 'Regional Processing Hub';
        specialty = u.collectorVerification?.businessDetails || 'Cold Extraction & Centrifugal Processing';
        license = u.collectorVerification?.licenseNumber || u.licenseNumber || 'FSSAI Certified';
      } else if (targetRole === 'LAB') {
        locStr = u.labVerification?.labAddress || u.facilityLocation || 'Quality Testing Lab Hub';
        specialty = u.labVerification?.authorizedTestingDetails || 'Physicochemical & Spectrometry Testing (Moisture, HMF, Diastase, Pollen)';
        license = u.labVerification?.labRegistrationNumber || u.labVerification?.accreditation || u.licenseNumber || 'NABL Accredited';
      } else if (targetRole === 'PACKAGING') {
        locStr = u.packagingVerification?.facilityLocation || u.facilityLocation || 'Sterile Bottling Facility';
        specialty = u.packagingVerification?.authorizedPackagingDetails || 'Automated Cleanroom Bottling, Tamper-Evident Seals, QR Code Generation';
        license = u.packagingVerification?.packagingLicenseNumber || u.licenseNumber || 'FSSAI Packaging License';
      }

      const centerCoords = parseCoordinates(locStr) || { lat: originCoords!.lat + 0.05, lng: originCoords!.lng + 0.05 };
      const distanceKm = calculateHaversineDistanceKm(
        originCoords!.lat,
        originCoords!.lng,
        centerCoords.lat,
        centerCoords.lng
      );

      return {
        id: u.id,
        name: u.organizationName || u.name,
        organizationName: u.organizationName || u.name,
        managerName: u.name,
        role: u.role,
        address: locStr,
        phone: u.phone,
        email: u.email,
        licenseNumber: license,
        specialtyDetails: specialty,
        distanceKm,
        distanceDisplay: `${distanceKm} km away`,
        isVerified: true,
        verificationBadge: 'Verified Centre ✓',
        coordinates: centerCoords
      };
    });

    // Sort ascending by distance (nearest first)
    results.sort((a, b) => a.distanceKm - b.distanceKm);

    res.json({
      success: true,
      origin: originCoords,
      targetRole,
      count: results.length,
      centers: results
    });
  } catch (error: any) {
    console.error('Error finding nearest centers:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 1. POST /api/requests
 * Create a new workflow request (e.g. Harvester -> Collection)
 * ─────────────────────────────────────────────────────────
 */
router.post('/requests', async (req: Request, res: Response) => {
  try {
    const {
      batchId,
      harvesterId,
      fromUserId,
      toUserId,
      fromRole = 'HARVESTER',
      toRole = 'COLLECTOR_PROCESSOR',
      requestType = 'HARVEST_TO_COLLECTION',
      quantity,
      unit = 'kg',
      notes,
      metadata
    } = req.body;

    if (!batchId) {
      return res.status(400).json({ success: false, error: 'batchId is required' });
    }

    // Verify batch exists
    const batch = await prisma.batch.findUnique({
      where: { id: batchId },
      include: { harvest: { include: { harvester: true } } }
    });

    if (!batch) {
      return res.status(404).json({ success: false, error: `Batch ${batchId} not found` });
    }

    // Check for existing pending request on this batch to avoid duplicates
    const activeRequest = await prisma.workflowRequest.findFirst({
      where: {
        batchId,
        status: { in: ['PENDING', 'ACCEPTED', 'IN_PROGRESS'] }
      }
    });

    if (activeRequest) {
      return res.status(400).json({
        success: false,
        error: `Batch ${batchId} already has an active request (${activeRequest.requestId} with status ${activeRequest.status})`
      });
    }

    const senderIdentifier = fromUserId || harvesterId || batch.harvest.harvesterId;
    const sender = await ensureUser(senderIdentifier, fromRole);
    if (!isProfileComplete(sender)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }
    if (normalizeRole(fromRole) === 'HARVESTER' || sender.role === 'HARVESTER') {
      const harvesterVer = await prisma.harvesterVerification.findUnique({
        where: { harvesterId: sender.id }
      });
      if (!isHarvesterFullyVerified(harvesterVer)) {
        return res.status(403).json(HARVESTER_VERIFICATION_REQUIRED_RESPONSE);
      }
    }
    const receiver = toUserId ? await ensureUser(toUserId, toRole) : null;

    const prefix = toRole.includes('COLLECT') ? 'COL' : toRole.includes('LAB') ? 'LAB' : 'PKG';
    const requestId = generateRequestId(prefix);
    const effectiveQty = quantity !== undefined ? Number(quantity) : batch.harvest.quantity;

    // Database transaction
    const result = await prisma.$transaction(async (tx) => {
      const newRequest = await tx.workflowRequest.create({
        data: {
          requestId,
          batchId,
          fromUserId: sender.id,
          toUserId: receiver?.id || null,
          fromRole: normalizeRole(fromRole),
          toRole: normalizeRole(toRole),
          requestType,
          status: 'PENDING',
          quantity: effectiveQty,
          unit,
          notes: notes || 'Harvest sent for collection & processing',
          metadata: metadata ? JSON.stringify(metadata) : null
        }
      });

      // Update batch stage
      await tx.batch.update({
        where: { id: batchId },
        data: {
          status: 'PENDING_COLLECTION',
          currentStage: 'COLLECTION'
        }
      });

      // Audit log in RequestHistory
      await tx.requestHistory.create({
        data: {
          requestId: newRequest.id,
          batchId,
          action: 'CREATED',
          fromStatus: null,
          toStatus: 'PENDING',
          actorId: sender.id,
          actorRole: normalizeRole(fromRole),
          notes: notes || 'Initiated collection request'
        }
      });

      return newRequest;
    });

    // Record on blockchain
    const prov = await recordWorkflowProvenance(
      batchId,
      'HARVEST_SENT_TO_COLLECTION',
      sender.id,
      result.id,
      { requestId: result.requestId, batchId, quantity: effectiveQty, harvesterId: sender.id }
    );

    res.status(201).json({
      success: true,
      message: 'Workflow request created successfully',
      request: result,
      provenance: prov.provEvent,
      blockchainStatus: prov.onChainResult.status
    });
  } catch (error: any) {
    console.error('Error creating request:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 2. GET /api/requests
 * List workflow requests with rich filtering
 * ─────────────────────────────────────────────────────────
 */
router.get('/requests', async (req: Request, res: Response) => {
  try {
    const {
      role,
      status,
      type,
      batchId,
      userId,
      direction = 'all' // 'incoming', 'outgoing', 'all'
    } = req.query;

    const where: any = {};

    if (batchId) {
      where.batchId = String(batchId);
    }

    if (status) {
      const statusStr = String(status).toUpperCase();
      if (statusStr !== 'ALL') {
        where.status = statusStr;
      }
    }

    if (type) {
      where.requestType = String(type);
    }

    if (role) {
      const normRole = normalizeRole(String(role));
      if (direction === 'incoming') {
        where.toRole = normRole;
      } else if (direction === 'outgoing') {
        where.fromRole = normRole;
      } else {
        where.OR = [
          { toRole: normRole },
          { fromRole: normRole }
        ];
      }
    }

    if (userId) {
      const user = await prisma.user.findFirst({
        where: { OR: [{ id: String(userId) }, { name: String(userId) }, { email: String(userId) }] }
      });
      if (user) {
        if (direction === 'incoming') {
          where.toUserId = user.id;
        } else if (direction === 'outgoing') {
          where.fromUserId = user.id;
        }
      }
    }

    const requests = await prisma.workflowRequest.findMany({
      where,
      include: {
        batch: {
          include: {
            harvest: { include: { harvester: true, hive: true } }
          }
        },
        fromUser: true,
        toUser: true,
        history: { orderBy: { createdAt: 'desc' }, include: { actor: true } },
        processingRecord: true,
        labReport: true,
        packagingRecord: true,
        provenanceEvents: { orderBy: { timestamp: 'desc' } }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(requests);
  } catch (error: any) {
    console.error('Error fetching requests:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 3. GET /api/requests/:id
 * Get single request details
 * ─────────────────────────────────────────────────────────
 */
router.get('/requests/:id', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const request = await prisma.workflowRequest.findFirst({
      where: {
        OR: [{ id }, { requestId: id }]
      },
      include: {
        batch: {
          include: {
            harvest: { include: { harvester: true, hive: true } },
            processingRecords: true,
            labReports: true,
            packagingRecords: true
          }
        },
        fromUser: true,
        toUser: true,
        previousRequest: true,
        nextRequests: true,
        history: { orderBy: { createdAt: 'asc' }, include: { actor: true } },
        processingRecord: true,
        labReport: true,
        packagingRecord: true,
        provenanceEvents: { orderBy: { timestamp: 'asc' } }
      }
    });

    if (!request) {
      return res.status(404).json({ success: false, error: `Request ${id} not found` });
    }

    res.json(request);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 4. PATCH /api/requests/:id/accept
 * Accept a pending request (Role-guarded & State-guarded)
 * ─────────────────────────────────────────────────────────
 */
router.patch('/requests/:id/accept', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const { actorId, actorRole, notes } = req.body;

    const request = await prisma.workflowRequest.findFirst({
      where: { OR: [{ id }, { requestId: id }] }
    });

    if (!request) {
      return res.status(404).json({ success: false, error: `Request ${id} not found` });
    }

    if (request.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        error: `Cannot accept request with status ${request.status}. Only PENDING requests can be accepted.`
      });
    }

    // Role authorization check
    const normalizedActorRole = normalizeRole(actorRole || request.toRole);
    if (normalizedActorRole !== request.toRole && normalizedActorRole !== 'ADMIN') {
      return res.status(403).json({
        success: false,
        error: `Unauthorized. Role ${normalizedActorRole} cannot accept requests assigned to ${request.toRole}.`
      });
    }

    const actor = await ensureUser(actorId || 'Role Officer', normalizedActorRole);
    if (!isProfileComplete(actor)) {
      return res.status(403).json({
        success: false,
        code: 'PROFILE_INCOMPLETE',
        error: 'Please complete your profile and required verification details before continuing with this request.'
      });
    }

    // Strict Collection & Processing Gate: Check that Collector profile is 3/3 verified
    if (normalizedActorRole === 'COLLECTOR_PROCESSOR' || request.requestType === 'HARVEST_TO_COLLECTION') {
      const colVer = await prisma.collectorVerification.findUnique({
        where: { collectorId: actor.id }
      });
      if (!isCollectorFullyVerified(colVer)) {
        return res.status(403).json(COLLECTOR_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    // Strict Lab Tester Gate: Check that Lab Tester profile is 3/3 verified
    if (normalizedActorRole === 'LAB' || request.requestType === 'COLLECTION_TO_LAB') {
      const labVer = await prisma.labVerification.findUnique({
        where: { labId: actor.id }
      });
      if (!isLabTesterFullyVerified(labVer)) {
        return res.status(403).json(LAB_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    // Strict Packaging Manager Gate: Check that Packaging Manager profile is 3/3 verified
    if (normalizedActorRole === 'PACKAGING' || request.requestType === 'LAB_TO_PACKAGING') {
      const pkgVer = await prisma.packagingVerification.findUnique({
        where: { packagerId: actor.id }
      });
      if (!isPackagingManagerFullyVerified(pkgVer)) {
        return res.status(403).json(PACKAGING_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    let nextBatchStatus = 'ACCEPTED';
    let provEventType = 'REQUEST_ACCEPTED';

    if (request.requestType === 'HARVEST_TO_COLLECTION') {
      nextBatchStatus = 'COLLECTION_ACCEPTED';
      provEventType = 'COLLECTION_ACCEPTED';
    } else if (request.requestType === 'COLLECTION_TO_LAB') {
      nextBatchStatus = 'LAB_ACCEPTED';
      provEventType = 'LAB_ACCEPTED';
    } else if (request.requestType === 'LAB_TO_PACKAGING') {
      nextBatchStatus = 'PACKAGING_ACCEPTED';
      provEventType = 'PACKAGING_ACCEPTED';
    }

    // Update in database transaction
    const updatedRequest = await prisma.$transaction(async (tx) => {
      const updated = await tx.workflowRequest.update({
        where: { id: request.id },
        data: {
          status: 'ACCEPTED',
          toUserId: actor.id,
          acceptedAt: new Date(),
          notes: notes ? `${request.notes ? request.notes + ' | ' : ''}${notes}` : request.notes
        }
      });

      await tx.batch.update({
        where: { id: request.batchId },
        data: { status: nextBatchStatus }
      });

      await tx.requestHistory.create({
        data: {
          requestId: request.id,
          batchId: request.batchId,
          action: 'ACCEPTED',
          fromStatus: 'PENDING',
          toStatus: 'ACCEPTED',
          actorId: actor.id,
          actorRole: normalizedActorRole,
          notes: notes || `Request accepted by ${normalizedActorRole}`
        }
      });

      return updated;
    });

    // Record on blockchain
    const prov = await recordWorkflowProvenance(
      request.batchId,
      provEventType,
      actor.id,
      request.id,
      { requestId: request.requestId, action: 'ACCEPTED', actorId: actor.id }
    );

    res.json({
      success: true,
      message: `Request ${request.requestId} accepted`,
      request: updatedRequest,
      provenance: prov.provEvent,
      blockchainStatus: prov.onChainResult.status
    });
  } catch (error: any) {
    console.error('Error accepting request:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 5. PATCH /api/requests/:id/reject
 * Reject a request with reason
 * ─────────────────────────────────────────────────────────
 */
router.patch('/requests/:id/reject', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const { actorId, actorRole, reason } = req.body;

    const request = await prisma.workflowRequest.findFirst({
      where: { OR: [{ id }, { requestId: id }] }
    });

    if (!request) {
      return res.status(404).json({ success: false, error: `Request ${id} not found` });
    }

    if (request.status === 'COMPLETED' || request.status === 'REJECTED') {
      return res.status(400).json({
        success: false,
        error: `Cannot reject request with status ${request.status}.`
      });
    }

    const normalizedActorRole = normalizeRole(actorRole || request.toRole);
    const actor = await ensureUser(actorId || 'Role Officer', normalizedActorRole);
    if (!isProfileComplete(actor)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    // Strict Collection & Processing Gate
    if (normalizedActorRole === 'COLLECTOR_PROCESSOR' || request.requestType === 'HARVEST_TO_COLLECTION') {
      const colVer = await prisma.collectorVerification.findUnique({
        where: { collectorId: actor.id }
      });
      if (!isCollectorFullyVerified(colVer)) {
        return res.status(403).json(COLLECTOR_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    // Strict Lab Tester Gate
    if (normalizedActorRole === 'LAB' || request.requestType === 'COLLECTION_TO_LAB') {
      const labVer = await prisma.labVerification.findUnique({
        where: { labId: actor.id }
      });
      if (!isLabTesterFullyVerified(labVer)) {
        return res.status(403).json(LAB_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    // Strict Packaging Manager Gate
    if (normalizedActorRole === 'PACKAGING' || request.requestType === 'LAB_TO_PACKAGING') {
      const pkgVer = await prisma.packagingVerification.findUnique({
        where: { packagerId: actor.id }
      });
      if (!isPackagingManagerFullyVerified(pkgVer)) {
        return res.status(403).json(PACKAGING_VERIFICATION_REQUIRED_RESPONSE);
      }
    }

    let nextBatchStatus = 'REJECTED';
    let provEventType = 'REQUEST_REJECTED';

    if (request.requestType === 'HARVEST_TO_COLLECTION') {
      nextBatchStatus = 'COLLECTION_REJECTED';
      provEventType = 'COLLECTION_REJECTED';
    } else if (request.requestType === 'COLLECTION_TO_LAB') {
      nextBatchStatus = 'LAB_REJECTED';
      provEventType = 'LAB_REJECTED';
    } else if (request.requestType === 'LAB_TO_PACKAGING') {
      nextBatchStatus = 'PACKAGING_REJECTED';
      provEventType = 'PACKAGING_REJECTED';
    }

    const rejectionReason = reason || 'Rejected by authorized role reviewer';

    const updatedRequest = await prisma.$transaction(async (tx) => {
      const updated = await tx.workflowRequest.update({
        where: { id: request.id },
        data: {
          status: 'REJECTED',
          rejectedAt: new Date(),
          notes: `${request.notes ? request.notes + ' | Rejection reason: ' : 'Rejection reason: '}${rejectionReason}`
        }
      });

      await tx.batch.update({
        where: { id: request.batchId },
        data: { status: nextBatchStatus }
      });

      await tx.requestHistory.create({
        data: {
          requestId: request.id,
          batchId: request.batchId,
          action: 'REJECTED',
          fromStatus: request.status,
          toStatus: 'REJECTED',
          actorId: actor.id,
          actorRole: normalizedActorRole,
          notes: rejectionReason
        }
      });

      return updated;
    });

    const prov = await recordWorkflowProvenance(
      request.batchId,
      provEventType,
      actor.id,
      request.id,
      { requestId: request.requestId, action: 'REJECTED', reason: rejectionReason }
    );

    res.json({
      success: true,
      message: `Request ${request.requestId} rejected`,
      request: updatedRequest,
      provenance: prov.provEvent,
      blockchainStatus: prov.onChainResult.status
    });
  } catch (error: any) {
    console.error('Error rejecting request:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 6. POST /api/requests/:id/send-next
 * Transition forward to next sequential stage
 * (Stage 1 -> Stage 2, or Stage 2 -> Stage 3)
 * ─────────────────────────────────────────────────────────
 */
router.post('/requests/:id/send-next', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const {
      actorId,
      actorRole,
      toUserId,
      targetLabId,
      targetPackagerId,
      quantityReceived,
      quantityAfter,
      method,
      moistureAtReceipt,
      notes
    } = req.body;

    const currentRequest = await prisma.workflowRequest.findFirst({
      where: { OR: [{ id }, { requestId: id }] },
      include: { batch: true, labReport: true }
    });

    if (!currentRequest) {
      return res.status(404).json({ success: false, error: `Request ${id} not found` });
    }

    const batch = currentRequest.batch;
    const normalizedActorRole = normalizeRole(actorRole);

    // ── Transition Case 1: Collection & Processing -> Lab Testing ──
    if (currentRequest.requestType === 'HARVEST_TO_COLLECTION') {
      if (currentRequest.status !== 'ACCEPTED' && currentRequest.status !== 'IN_PROGRESS') {
        return res.status(400).json({
          success: false,
          error: `Stage 1 request must be ACCEPTED before sending to Lab. Current status: ${currentRequest.status}`
        });
      }

      if (normalizedActorRole !== 'COLLECTOR_PROCESSOR' && normalizedActorRole !== 'ADMIN') {
        return res.status(403).json({
          success: false,
          error: `Unauthorized. Only Collector/Processor can send batch to Lab.`
        });
      }

      const processor = await ensureUser(actorId || 'Processor', 'COLLECTOR_PROCESSOR');
      if (!isProfileComplete(processor)) {
        return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
      }
      const colVer = await prisma.collectorVerification.findUnique({
        where: { collectorId: processor.id }
      });
      if (!isCollectorFullyVerified(colVer)) {
        return res.status(403).json(COLLECTOR_VERIFICATION_REQUIRED_RESPONSE);
      }

      const targetLabUser = (toUserId || targetLabId) ? await ensureUser(toUserId || targetLabId, 'LAB') : null;

      const nextRequestId = generateRequestId('LAB');
      const qtyIn = quantityReceived !== undefined ? Number(quantityReceived) : (currentRequest.quantity || 0);
      const qtyOut = quantityAfter !== undefined ? Number(quantityAfter) : qtyIn;

      const result = await prisma.$transaction(async (tx) => {
        // 1. Create Processing Record
        const procRecord = await tx.processingRecord.create({
          data: {
            batchId: batch.id,
            processorId: processor.id,
            requestId: currentRequest.id,
            quantityReceived: qtyIn,
            quantityAfter: qtyOut,
            method: method || 'Standard Cold Extraction',
            moistureAtReceipt: moistureAtReceipt ? Number(moistureAtReceipt) : null,
            notes: notes || 'Extraction completed'
          }
        });

        // 2. Complete Current Request
        await tx.workflowRequest.update({
          where: { id: currentRequest.id },
          data: {
            status: 'COMPLETED',
            completedAt: new Date()
          }
        });

        // 3. Create Stage 2 Request: Collection -> Lab
        const nextReq = await tx.workflowRequest.create({
          data: {
            requestId: nextRequestId,
            batchId: batch.id,
            fromUserId: processor.id,
            toUserId: targetLabUser?.id || null,
            fromRole: 'COLLECTOR_PROCESSOR',
            toRole: 'LAB',
            requestType: 'COLLECTION_TO_LAB',
            status: 'PENDING',
            previousRequestId: currentRequest.id,
            quantity: qtyOut,
            unit: 'kg',
            notes: notes || `Extracted honey sample ready for lab analysis (${qtyOut} kg)`
          }
        });

        // 4. Update Batch Status & Stage
        await tx.batch.update({
          where: { id: batch.id },
          data: {
            status: 'PENDING_LAB',
            currentStage: 'LAB'
          }
        });

        // 5. Request History
        await tx.requestHistory.create({
          data: {
            requestId: nextReq.id,
            batchId: batch.id,
            action: 'SENT_TO_LAB',
            fromStatus: 'PROCESSING_COMPLETED',
            toStatus: 'PENDING',
            actorId: processor.id,
            actorRole: 'COLLECTOR_PROCESSOR',
            notes: `Batch processed (${qtyOut} kg) and sample forwarded to ${targetLabUser ? targetLabUser.name : 'Lab'}`
          }
        });

        return { procRecord, nextReq };
      });

      // Blockchain event
      const prov = await recordWorkflowProvenance(
        batch.id,
        'COLLECTION_SENT_TO_LAB',
        processor.id,
        result.nextReq.id,
        {
          requestId: result.nextReq.requestId,
          batchId: batch.id,
          quantity: qtyOut,
          processorId: processor.id,
          method: method || 'Standard Cold Extraction'
        }
      );

      return res.json({
        success: true,
        message: 'Batch processed and sent to Lab Testing',
        processingRecord: result.procRecord,
        nextRequest: result.nextReq,
        provenance: prov.provEvent,
        blockchainStatus: prov.onChainResult.status
      });
    }

    // ── Transition Case 2: Lab Testing -> Packaging ──
    if (currentRequest.requestType === 'COLLECTION_TO_LAB') {
      if (currentRequest.status !== 'VERIFIED') {
        return res.status(400).json({
          success: false,
          error: `Batch must be LAB_VERIFIED before approving for packaging. Current status: ${currentRequest.status}`
        });
      }

      if (normalizedActorRole !== 'LAB' && normalizedActorRole !== 'ADMIN') {
        return res.status(403).json({
          success: false,
          error: `Unauthorized. Only Lab personnel can approve batch for Packaging.`
        });
      }

      const labOfficer = await ensureUser(actorId || 'Lab Officer', 'LAB');
      if (!isProfileComplete(labOfficer)) {
        return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
      }
      const labVer = await prisma.labVerification.findUnique({
        where: { labId: labOfficer.id }
      });
      if (!isLabTesterFullyVerified(labVer)) {
        return res.status(403).json(LAB_VERIFICATION_REQUIRED_RESPONSE);
      }

      const targetPackagerUser = (toUserId || targetPackagerId) ? await ensureUser(toUserId || targetPackagerId, 'PACKAGING') : null;

      const nextRequestId = generateRequestId('PKG');

      const result = await prisma.$transaction(async (tx) => {
        // 1. Complete Current Lab Request
        await tx.workflowRequest.update({
          where: { id: currentRequest.id },
          data: {
            status: 'COMPLETED',
            completedAt: new Date()
          }
        });

        // 2. Create Stage 3 Request: Lab -> Packaging
        const nextReq = await tx.workflowRequest.create({
          data: {
            requestId: nextRequestId,
            batchId: batch.id,
            fromUserId: labOfficer.id,
            toUserId: targetPackagerUser?.id || null,
            fromRole: 'LAB',
            toRole: 'PACKAGING',
            requestType: 'LAB_TO_PACKAGING',
            status: 'PENDING',
            previousRequestId: currentRequest.id,
            quantity: currentRequest.quantity,
            unit: 'kg',
            notes: notes || 'Verified batch approved and forwarded for packaging'
          }
        });

        // 3. Update Batch Status & Stage
        await tx.batch.update({
          where: { id: batch.id },
          data: {
            status: 'PENDING_PACKAGING',
            currentStage: 'PACKAGING'
          }
        });

        // 4. Request History
        await tx.requestHistory.create({
          data: {
            requestId: nextReq.id,
            batchId: batch.id,
            action: 'APPROVED_FOR_PACKAGING',
            fromStatus: 'LAB_VERIFIED',
            toStatus: 'PENDING',
            actorId: labOfficer.id,
            actorRole: 'LAB',
            notes: notes || `Lab verification complete; approved for packaging with ${targetPackagerUser ? targetPackagerUser.name : 'Packaging Facility'}`
          }
        });

        return nextReq;
      });

      const prov = await recordWorkflowProvenance(
        batch.id,
        'LAB_SENT_TO_PACKAGING',
        labOfficer.id,
        result.id,
        {
          requestId: result.requestId,
          batchId: batch.id,
          labOfficerId: labOfficer.id,
          labReportId: currentRequest.labReport?.id
        }
      );

      return res.json({
        success: true,
        message: 'Batch approved and sent to Packaging',
        nextRequest: result,
        provenance: prov.provEvent,
        blockchainStatus: prov.onChainResult.status
      });
    }

    return res.status(400).json({
      success: false,
      error: `Invalid request type ${currentRequest.requestType} for send-next transition`
    });
  } catch (error: any) {
    console.error('Error sending to next stage:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 7. POST /api/lab-reports
 * Submit lab testing results and verify batch
 * ─────────────────────────────────────────────────────────
 */
router.post('/lab-reports', async (req: Request, res: Response) => {
  try {
    const {
      batchId,
      requestId,
      labId,
      testResults,
      qualityScore = 95.0,
      moistureContent = 16.8,
      purityGrade = 'Grade A',
      contaminantsFound = 'None',
      moistureValue,
      hmfValue = 12.4,
      diastaseValue = 14.2,
      purityValue = 1.15,
      residuesValue = 'None Detected',
      pollenValue = 'Authentic Floral Matrix',
      sampleCode,
      remarks,
      notes
    } = req.body;

    if (!batchId) {
      return res.status(400).json({ success: false, error: 'batchId is required' });
    }

    // Find active lab request
    let request = requestId
      ? await prisma.workflowRequest.findFirst({ where: { OR: [{ id: requestId }, { requestId }] } })
      : await prisma.workflowRequest.findFirst({
          where: {
            batchId,
            requestType: 'COLLECTION_TO_LAB',
            status: { in: ['PENDING', 'ACCEPTED', 'IN_PROGRESS'] }
          }
        });

    if (!request) {
      return res.status(400).json({
        success: false,
        error: `No active Lab request found for batch ${batchId}. A batch must be sent to lab first.`
      });
    }

    // Strict Workflow Rule: Testing cannot start without an accepted request
    if (request.status !== 'ACCEPTED' && request.status !== 'IN_PROGRESS') {
      return res.status(400).json({
        success: false,
        error: `Lab testing cannot start without an accepted request. Current request status is "${request.status}". Please accept the sample request first.`
      });
    }

    const labUser = await ensureUser(labId || 'Lab Officer', 'LAB');
    if (!isProfileComplete(labUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    // Strict 3/3 Profile Verification Check
    const labVer = await prisma.labVerification.findUnique({
      where: { labId: labUser.id }
    });
    if (!isLabTesterFullyVerified(labVer)) {
      return res.status(403).json(LAB_VERIFICATION_REQUIRED_RESPONSE);
    }

    // Parameter values & limits
    const finalMoisture = Number(moistureValue !== undefined ? moistureValue : moistureContent) || 16.8;
    const finalHmf = Number(hmfValue) || 12.0;
    const finalDiastase = Number(diastaseValue) || 14.0;
    const finalPurity = Number(purityValue) || 1.1;
    const finalScore = Number(qualityScore) || 92.0;

    const moisturePass = finalMoisture <= 20.0;
    const hmfPass = finalHmf <= 40.0;
    const diastasePass = finalDiastase >= 8.0;
    const purityPass = finalPurity >= 0.95;
    const residuesPass = String(residuesValue).toLowerCase().includes('none') || String(residuesValue).toLowerCase().includes('nd') || String(residuesValue) === '0';
    const pollenPass = !String(pollenValue).toLowerCase().includes('adulterat') && !String(pollenValue).toLowerCase().includes('fail');

    const isQualityApproved = moisturePass && hmfPass && diastasePass && purityPass && residuesPass && pollenPass && finalScore >= 70.0;
    const reportStatus = isQualityApproved ? 'APPROVED' : 'REJECTED';
    const overallResult = isQualityApproved ? 'PASS' : 'FAIL';
    const nextReqStatus = isQualityApproved ? 'VERIFIED' : 'REJECTED';
    const nextBatchStatus = isQualityApproved ? 'LAB_VERIFIED' : 'LAB_REJECTED';

    const generatedReportId = `LAB-RPT-2026-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const generatedTraceId = `HC-TRACE-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const signatureHash = crypto.createHash('sha256').update(`${generatedReportId}:${labUser.id}:${batchId}:${Date.now()}`).digest('hex');

    const result = await prisma.$transaction(async (tx) => {
      // 1. Create Comprehensive Lab Report
      const report = await tx.labReport.create({
        data: {
          reportId: generatedReportId,
          qrTraceabilityId: generatedTraceId,
          batchId,
          labId: labUser.id,
          requestId: request.id,
          testResults: testResults || `Moisture: ${finalMoisture}%, HMF: ${finalHmf} mg/kg, Diastase: ${finalDiastase}, Score: ${finalScore}/100`,
          qualityScore: finalScore,
          moistureContent: finalMoisture,
          purityGrade: String(purityGrade),
          contaminantsFound: String(contaminantsFound || 'None'),
          status: reportStatus,
          overallResult,
          moistureValue: finalMoisture,
          moistureLimit: '<= 20.0%',
          moistureStatus: moisturePass ? 'PASS' : 'FAIL',
          hmfValue: finalHmf,
          hmfLimit: '<= 40.0 mg/kg',
          hmfStatus: hmfPass ? 'PASS' : 'FAIL',
          diastaseValue: finalDiastase,
          diastaseLimit: '>= 8.0 Schade Units',
          diastaseStatus: diastasePass ? 'PASS' : 'FAIL',
          purityValue: finalPurity,
          purityLimit: '>= 0.95 F/G Ratio',
          purityStatus: purityPass ? 'PASS' : 'FAIL',
          residuesValue: String(residuesValue),
          residuesLimit: '0.0 ppm (None Detected)',
          residuesStatus: residuesPass ? 'PASS' : 'FAIL',
          pollenValue: String(pollenValue),
          pollenLimit: 'Botanical Origin Authentic',
          pollenStatus: pollenPass ? 'PASS' : 'FAIL',
          labTesterName: labVer?.fullName || labUser.name,
          labName: labVer?.labName || labUser.organizationName || 'HoneyChain Certified Testing Laboratory',
          testDate: new Date(),
          sampleCode: sampleCode || `SMP-${batchId.slice(-6)}`,
          remarks: remarks || notes || (isQualityApproved ? 'All physicochemical parameters conform to FSSAI & Codex Honey Standards.' : 'Sample failed quality or purity thresholds.'),
          testerSignatureHash: signatureHash,
          notes: notes || ''
        }
      });

      // 2. Update Request Status
      const updatedReq = await tx.workflowRequest.update({
        where: { id: request.id },
        data: {
          status: nextReqStatus,
          toUserId: labUser.id,
          completedAt: new Date(),
          metadata: JSON.stringify({
            reportId: generatedReportId,
            qualityScore: finalScore,
            moistureContent: finalMoisture,
            overallResult,
            purityGrade: String(purityGrade)
          })
        }
      });

      // 3. Update Batch
      await tx.batch.update({
        where: { id: batchId },
        data: { status: nextBatchStatus }
      });

      // 4. Request History
      await tx.requestHistory.create({
        data: {
          requestId: request.id,
          batchId,
          action: isQualityApproved ? 'TESTED' : 'REJECTED',
          fromStatus: request.status,
          toStatus: nextReqStatus,
          actorId: labUser.id,
          actorRole: 'LAB',
          notes: `Lab testing complete: ${overallResult} (Report: ${generatedReportId}, Moisture: ${finalMoisture}%, HMF: ${finalHmf} mg/kg)`
        }
      });

      return { report, updatedReq };
    });

    const prov = await recordWorkflowProvenance(
      batchId,
      isQualityApproved ? 'LAB_VERIFIED' : 'LAB_REJECTED',
      labUser.id,
      request.id,
      {
        reportId: generatedReportId,
        qualityScore: finalScore,
        moistureContent: finalMoisture,
        hmfValue: finalHmf,
        diastaseValue: finalDiastase,
        overallResult,
        status: reportStatus
      }
    );

    res.json({
      success: true,
      message: isQualityApproved ? 'Lab report generated & honey batch verified.' : 'Lab test completed with failure/rejection recorded.',
      report: result.report,
      request: result.updatedReq,
      provenance: prov.onChainResult
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 8. POST /api/packaging
 * Finalize packaging, generate QR, and complete batch workflow
 * ─────────────────────────────────────────────────────────
 */
router.post('/packaging', async (req: Request, res: Response) => {
  try {
    const {
      batchId,
      requestId,
      packagerId,
      finalQuantity,
      numberOfPackages,
      packageSize = '500g Glass Jar',
      notes
    } = req.body;

    if (!batchId) {
      return res.status(400).json({ success: false, error: 'batchId is required' });
    }

    const batch = await prisma.batch.findUnique({
      where: { id: batchId },
      include: { labReports: true }
    });

    if (!batch) {
      return res.status(404).json({ success: false, error: `Batch ${batchId} not found` });
    }

    // Security check: cannot package without lab verification
    const verifiedLabReport = batch.labReports.find((r) => r.status === 'APPROVED' || r.overallResult === 'PASS');
    if (!verifiedLabReport) {
      return res.status(400).json({
        success: false,
        error: 'Packaging forbidden. Batch has not passed lab verification.'
      });
    }

    // Find active packaging request
    let request = requestId
      ? await prisma.workflowRequest.findFirst({ where: { OR: [{ id: requestId }, { requestId }] } })
      : await prisma.workflowRequest.findFirst({
          where: {
            batchId,
            requestType: 'LAB_TO_PACKAGING',
            status: { in: ['PENDING', 'ACCEPTED', 'IN_PROGRESS'] }
          }
        });

    if (request && request.status !== 'ACCEPTED' && request.status !== 'IN_PROGRESS') {
      return res.status(400).json({
        success: false,
        error: `Packaging cannot be finalized without an accepted request. Current request status is "${request.status}". Please accept the packaging request first.`
      });
    }

    const packagerUser = await ensureUser(packagerId || 'Packager', 'PACKAGING');
    if (!isProfileComplete(packagerUser)) {
      return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
    }

    // Strict 3/3 Profile Verification Check
    const pkgVer = await prisma.packagingVerification.findUnique({
      where: { packagerId: packagerUser.id }
    });
    if (!isPackagingManagerFullyVerified(pkgVer)) {
      return res.status(403).json(PACKAGING_VERIFICATION_REQUIRED_RESPONSE);
    }

    const finalQty = finalQuantity !== undefined ? Number(finalQuantity) : (request?.quantity || 25.0);
    const numPkgs = numberOfPackages !== undefined ? Number(numberOfPackages) : 50;

    // Real verifiable QR link for provenance scanning
    const qrCodeUrl = `https://honeychain.io/verify?batch=${encodeURIComponent(batchId)}`;

    const result = await prisma.$transaction(async (tx) => {
      // 1. Create Packaging Record
      const pkgRecord = await tx.packagingRecord.create({
        data: {
          batchId,
          packagerId: packagerUser.id,
          requestId: request?.id || null,
          finalQuantity: finalQty,
          numberOfPackages: numPkgs,
          packageSize,
          notes: notes || 'Packaging sealed & QR verification assigned',
          qrCodeUrl
        }
      });

      // 2. Complete Request
      if (request) {
        await tx.workflowRequest.update({
          where: { id: request.id },
          data: {
            status: 'COMPLETED',
            toUserId: packagerUser.id,
            completedAt: new Date()
          }
        });

        await tx.requestHistory.create({
          data: {
            requestId: request.id,
            batchId,
            action: 'COMPLETED',
            fromStatus: request.status,
            toStatus: 'COMPLETED',
            actorId: packagerUser.id,
            actorRole: 'PACKAGING',
            notes: `Packaging completed: ${numPkgs} packages of ${packageSize} (${finalQty} kg total)`
          }
        });
      }

      // 3. Complete Batch
      const updatedBatch = await tx.batch.update({
        where: { id: batchId },
        data: {
          status: 'COMPLETED',
          currentStage: 'COMPLETED'
        }
      });

      return { pkgRecord, updatedBatch };
    });

    const prov = await recordWorkflowProvenance(
      batchId,
      'PACKAGING_COMPLETED',
      packagerUser.id,
      request?.id,
      {
        batchId,
        packagingRecordId: result.pkgRecord.id,
        finalQuantity: finalQty,
        numberOfPackages: numPkgs,
        qrCodeUrl
      }
    );

    res.json({
      success: true,
      message: 'Batch packaging finalized and verified on HoneyChain',
      packagingRecord: result.pkgRecord,
      batch: result.updatedBatch,
      qrVerificationUrl: qrCodeUrl,
      provenance: prov.provEvent,
      blockchainStatus: prov.onChainResult.status
    });
  } catch (error: any) {
    console.error('Error finalizing packaging:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 9. GET /api/batches/:id/workflow
 * Comprehensive batch lifecycle & request chain progress
 * ─────────────────────────────────────────────────────────
 */
router.get('/batches/:id/workflow', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);

    const batch = await prisma.batch.findUnique({
      where: { id },
      include: {
        harvest: {
          include: {
            harvester: {
              include: { harvesterVerification: true }
            },
            hive: true
          }
        },
        workflowRequests: {
          include: {
            fromUser: true,
            toUser: true,
            history: { orderBy: { createdAt: 'asc' }, include: { actor: true } },
            processingRecord: true,
            labReport: true,
            packagingRecord: true
          },
          orderBy: { createdAt: 'asc' }
        },
        processingRecords: { include: { processor: true } },
        labReports: { include: { lab: true } },
        packagingRecords: { include: { packager: true } },
        provenanceEvents: { orderBy: { timestamp: 'asc' } }
      }
    });

    if (!batch) {
      return res.status(404).json({ success: false, error: `Batch ${id} not found` });
    }

    // Determine workflow step statuses
    const hasHarvest = !!batch.harvest;
    const hasProcessing = batch.processingRecords.length > 0;
    const verifiedLab = batch.labReports.find((l) => l.status === 'APPROVED');
    const hasPackaging = batch.packagingRecords.length > 0;
    const isCompleted = batch.status === 'COMPLETED' || batch.currentStage === 'COMPLETED';

    const stages = [
      {
        stage: 'HARVEST',
        title: 'Honey Harvested',
        completed: hasHarvest,
        date: batch.harvest?.createdAt || batch.createdAt,
        actor: batch.harvest?.harvester?.name || 'Harvester',
        details: `${batch.harvest?.quantity || 0} kg from ${batch.harvest?.location || 'Apiary'}`
      },
      {
        stage: 'COLLECTION',
        title: 'Collection & Processing',
        completed: hasProcessing,
        date: batch.processingRecords[0]?.createdAt || null,
        actor: batch.processingRecords[0]?.processor?.name || null,
        details: batch.processingRecords[0]
          ? `${batch.processingRecords[0].method} (${batch.processingRecords[0].quantityAfter} kg)`
          : 'Pending collection'
      },
      {
        stage: 'LAB',
        title: 'Lab Testing & Verification',
        completed: !!verifiedLab,
        date: verifiedLab?.createdAt || null,
        actor: verifiedLab?.lab?.name || null,
        details: verifiedLab
          ? `Score: ${verifiedLab.qualityScore}/100, Moisture: ${verifiedLab.moistureContent}%`
          : 'Pending test'
      },
      {
        stage: 'PACKAGING',
        title: 'Packaging & Sealing',
        completed: hasPackaging,
        date: batch.packagingRecords[0]?.createdAt || null,
        actor: batch.packagingRecords[0]?.packager?.name || null,
        details: batch.packagingRecords[0]
          ? `${batch.packagingRecords[0].numberOfPackages} packages (${batch.packagingRecords[0].packageSize})`
          : 'Pending packaging'
      },
      {
        stage: 'COMPLETED',
        title: 'Provenance Finalized',
        completed: isCompleted,
        date: batch.updatedAt,
        details: isCompleted ? 'Ledger verified and sealed' : 'Workflow in progress'
      }
    ];

    res.json({
      success: true,
      batchId: batch.id,
      status: batch.status,
      currentStage: batch.currentStage,
      stages,
      requests: batch.workflowRequests,
      harvest: batch.harvest,
      processing: batch.processingRecords[0] || null,
      labReport: verifiedLab || batch.labReports[0] || null,
      packaging: batch.packagingRecords[0] || null,
      provenanceEvents: batch.provenanceEvents
    });
  } catch (error: any) {
    console.error('Error fetching batch workflow:', error);
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * ─────────────────────────────────────────────────────────
 * 10. GET /api/batches/:id/history
 * Full audit timeline of all state transitions
 * ─────────────────────────────────────────────────────────
 */
router.get('/batches/:id/history', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);

    const history = await prisma.requestHistory.findMany({
      where: { batchId: id },
      include: { actor: true, request: true },
      orderBy: { createdAt: 'asc' }
    });

    const provenance = await prisma.provenanceEvent.findMany({
      where: { batchId: id },
      include: { actor: true },
      orderBy: { timestamp: 'asc' }
    });

    res.json({
      success: true,
      batchId: id,
      history,
      provenanceEvents: provenance
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;
