import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { isUserProfileComplete, PROFILE_INCOMPLETE_RESPONSE, BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE, HARVESTER_VERIFICATION_REQUIRED_RESPONSE, isHarvesterFullyVerified } from '../services/profileService';

const router = Router();
const prisma = new PrismaClient();

// Helper to generate unique collision-free hive code
export async function generateUniqueHiveCode(): Promise<string> {
  let isTaken = true;
  let code = '';
  while (isTaken) {
    const hex = crypto.randomBytes(3).toString('hex').toUpperCase();
    code = `HIVE-${hex}`;
    const found = await prisma.hive.findUnique({ where: { hiveCode: code } });
    if (!found) {
      isTaken = false;
    }
  }
  return code;
}

/**
 * GET /api/hives
 * Fetch all hives for the authenticated beekeeper with optional search/filter/sort
 */
router.get('/', async (req: Request, res: Response) => {
  try {
    const { search, filter, sort, userId: queryUserId, harvesterId, beekeeperId } = req.query;
    const headerUserId = req.headers['x-user-id'] as string;
    const targetUserId = (queryUserId as string) || (harvesterId as string) || (beekeeperId as string) || headerUserId;

    const whereClause: any = {};
    if (targetUserId && targetUserId.trim().length > 0) {
      whereClause.userId = targetUserId.trim();
    }

    const hives = await prisma.hive.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' }
    });

    let result = hives.map((h) => ({
      id: h.id,
      userId: h.userId,
      name: h.name,
      hiveCode: h.hiveCode,
      apiaryLocation: h.apiaryLocation,
      hiveType: h.hiveType,
      dateAdded: h.dateAdded.toISOString(),
      queenStatus: h.queenStatus,
      totalFrames: h.totalFrames,
      broodFrames: h.broodFrames,
      colonyStrength: h.colonyStrength,
      queenAgeMonths: h.queenAgeMonths,
      beeBreed: h.beeBreed,
      expectedProductionKg: h.expectedProductionKg,
      previousYearProductionKg: h.previousYearProductionKg,
      currentYearProductionKg: h.currentYearProductionKg,
      honeyType: h.honeyType,
      lastInspectionDate: h.lastInspectionDate.toISOString(),
      miteStatus: h.miteStatus,
      diseaseStatus: h.diseaseStatus,
      feedingRequired: h.feedingRequired,
      queenCondition: h.queenCondition,
      overallHealth: h.overallHealth,
      notes: h.notes || '',
      updatedAt: h.updatedAt.toISOString(),
    }));

    // Apply search filter if present
    if (search && typeof search === 'string' && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      result = result.filter((h) =>
        h.name.toLowerCase().includes(q) ||
        h.hiveCode.toLowerCase().includes(q) ||
        h.apiaryLocation.toLowerCase().includes(q) ||
        h.beeBreed.toLowerCase().includes(q) ||
        h.honeyType.toLowerCase().includes(q)
      );
    }

    // Apply status filter if present
    if (filter && typeof filter === 'string') {
      if (filter === 'Healthy') {
        result = result.filter((h) => h.overallHealth.toLowerCase() === 'healthy');
      } else if (filter === 'Needs Attention') {
        result = result.filter((h) => h.overallHealth.toLowerCase() !== 'healthy');
      } else if (filter === 'High Production') {
        result = result.filter((h) => h.currentYearProductionKg >= 25.0);
      }
    }

    // Apply sorting if present
    if (sort && typeof sort === 'string') {
      if (sort === 'Production High-Low') {
        result.sort((a, b) => b.currentYearProductionKg - a.currentYearProductionKg);
      } else if (sort === 'Last Inspected') {
        result.sort((a, b) => new Date(b.lastInspectionDate).getTime() - new Date(a.lastInspectionDate).getTime());
      } else if (sort === 'Date Added') {
        result.sort((a, b) => new Date(b.dateAdded).getTime() - new Date(a.dateAdded).getTime());
      } else if (sort === 'Name A-Z') {
        result.sort((a, b) => a.name.localeCompare(b.name));
      }
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/hives/code/generate
 * Authoritative generation of unique Hive Identity Code
 */
router.get('/code/generate', async (req: Request, res: Response) => {
  try {
    const code = await generateUniqueHiveCode();
    res.json({ success: true, code });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/hives/:id
 * Fetch a single hive by ID
 */
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const h = await prisma.hive.findUnique({ where: { id } });
    if (!h) {
      return res.status(404).json({ success: false, message: 'Hive not found' });
    }

    res.json({
      id: h.id,
      userId: h.userId,
      name: h.name,
      hiveCode: h.hiveCode,
      apiaryLocation: h.apiaryLocation,
      hiveType: h.hiveType,
      dateAdded: h.dateAdded.toISOString(),
      queenStatus: h.queenStatus,
      totalFrames: h.totalFrames,
      broodFrames: h.broodFrames,
      colonyStrength: h.colonyStrength,
      queenAgeMonths: h.queenAgeMonths,
      beeBreed: h.beeBreed,
      expectedProductionKg: h.expectedProductionKg,
      previousYearProductionKg: h.previousYearProductionKg,
      currentYearProductionKg: h.currentYearProductionKg,
      honeyType: h.honeyType,
      lastInspectionDate: h.lastInspectionDate.toISOString(),
      miteStatus: h.miteStatus,
      diseaseStatus: h.diseaseStatus,
      feedingRequired: h.feedingRequired,
      queenCondition: h.queenCondition,
      overallHealth: h.overallHealth,
      notes: h.notes || '',
      updatedAt: h.updatedAt.toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/hives
 * Create a new Hive record in PostgreSQL with strict Beekeeper Profile Gate and Unique Identifiers
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const data = req.body;
    if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'Hive name is required' });
    }

    // 1. Mandatory authenticated beekeeper identity resolution
    const rawUserId = data.userId || data.harvesterId || data.beekeeperId || (req.headers['x-user-id'] as string);
    if (!rawUserId || typeof rawUserId !== 'string' || rawUserId.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'AUTH_REQUIRED',
        message: 'Authenticated beekeeper ID (userId) is required to add a beehive.'
      });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { id: rawUserId.trim() },
          { email: rawUserId.trim().toLowerCase() }
        ]
      },
      include: {
        harvesterVerification: true
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'USER_NOT_FOUND',
        message: 'Beekeeper account not found for the provided ID.'
      });
    }

    // 2. Mandatory profile completion gate for Harvester/Beekeeper
    if (!isUserProfileComplete(user)) {
      return res.status(403).json(BEEKEEPER_PROFILE_INCOMPLETE_RESPONSE);
    }

    // 3. Mandatory Harvester Verification Gate
    if (user.role === 'HARVESTER' && !isHarvesterFullyVerified(user.harvesterVerification)) {
      return res.status(403).json(HARVESTER_VERIFICATION_REQUIRED_RESPONSE);
    }

    // 4. Unique Hive Code validation / generation
    let hiveCode = (data.hiveCode || '').trim();
    if (!hiveCode) {
      hiveCode = await generateUniqueHiveCode();
    } else {
      const existing = await prisma.hive.findUnique({ where: { hiveCode } });
      if (existing) {
        return res.status(409).json({ success: false, error: `Hive Code ${hiveCode} is already in use.` });
      }
    }

    // 4. Create authoritative Hive record
    const hive = await prisma.hive.create({
      data: {
        id: data.id || undefined,
        userId: user.id,
        name: data.name.trim(),
        hiveCode,
        apiaryLocation: data.apiaryLocation || 'Main Apiary',
        hiveType: data.hiveType || 'Langstroth',
        dateAdded: data.dateAdded ? new Date(data.dateAdded) : new Date(),
        queenStatus: data.queenStatus || 'Mated',
        totalFrames: data.totalFrames !== undefined && data.totalFrames !== null && data.totalFrames !== '' ? Number(data.totalFrames) : 10,
        broodFrames: data.broodFrames !== undefined && data.broodFrames !== null && data.broodFrames !== '' ? Number(data.broodFrames) : 0,
        colonyStrength: data.colonyStrength || 'Strong',
        queenAgeMonths: data.queenAgeMonths !== undefined && data.queenAgeMonths !== null && data.queenAgeMonths !== '' ? Number(data.queenAgeMonths) : 0,
        beeBreed: data.beeBreed || 'Italian',
        expectedProductionKg: data.expectedProductionKg !== undefined && data.expectedProductionKg !== null && data.expectedProductionKg !== '' ? Number(data.expectedProductionKg) : 0.0,
        previousYearProductionKg: data.previousYearProductionKg !== undefined && data.previousYearProductionKg !== null && data.previousYearProductionKg !== '' ? Number(data.previousYearProductionKg) : 0.0,
        currentYearProductionKg: data.currentYearProductionKg !== undefined && data.currentYearProductionKg !== null && data.currentYearProductionKg !== '' ? Number(data.currentYearProductionKg) : 0.0,
        honeyType: data.honeyType || 'Wildflower',
        lastInspectionDate: data.lastInspectionDate ? new Date(data.lastInspectionDate) : new Date(),
        miteStatus: data.miteStatus || 'None',
        diseaseStatus: data.diseaseStatus || 'None',
        feedingRequired: Boolean(data.feedingRequired),
        queenCondition: data.queenCondition || 'Good',
        overallHealth: data.overallHealth || 'Healthy',
        notes: data.notes || '',
      }
    });

    res.status(201).json({
      id: hive.id,
      userId: hive.userId,
      name: hive.name,
      hiveCode: hive.hiveCode,
      apiaryLocation: hive.apiaryLocation,
      hiveType: hive.hiveType,
      dateAdded: hive.dateAdded.toISOString(),
      queenStatus: hive.queenStatus,
      totalFrames: hive.totalFrames,
      broodFrames: hive.broodFrames,
      colonyStrength: hive.colonyStrength,
      queenAgeMonths: hive.queenAgeMonths,
      beeBreed: hive.beeBreed,
      expectedProductionKg: hive.expectedProductionKg,
      previousYearProductionKg: hive.previousYearProductionKg,
      currentYearProductionKg: hive.currentYearProductionKg,
      honeyType: hive.honeyType,
      lastInspectionDate: hive.lastInspectionDate.toISOString(),
      miteStatus: hive.miteStatus,
      diseaseStatus: hive.diseaseStatus,
      feedingRequired: hive.feedingRequired,
      queenCondition: hive.queenCondition,
      overallHealth: hive.overallHealth,
      notes: hive.notes || '',
      updatedAt: hive.updatedAt.toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * PUT /api/hives/:id
 * Update an existing Hive in PostgreSQL
 */
router.put('/:id', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const data = req.body;

    const existing = await prisma.hive.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: 'Hive not found' });
    }

    const rawUserId = data.userId || data.harvesterId || data.beekeeperId || (req.headers['x-user-id'] as string);
    if (rawUserId) {
      const user = await prisma.user.findFirst({
        where: {
          OR: [
            { id: rawUserId.trim() },
            { email: rawUserId.trim().toLowerCase() }
          ]
        },
        include: {
          harvesterVerification: true
        }
      });
      if (user) {
        if (!isUserProfileComplete(user)) {
          return res.status(403).json(PROFILE_INCOMPLETE_RESPONSE);
        }
        if (user.role === 'HARVESTER' && !isHarvesterFullyVerified(user.harvesterVerification)) {
          return res.status(403).json(HARVESTER_VERIFICATION_REQUIRED_RESPONSE);
        }
      }
    }

    if (data.hiveCode && data.hiveCode !== existing.hiveCode) {
      const codeCheck = await prisma.hive.findUnique({ where: { hiveCode: data.hiveCode } });
      if (codeCheck && codeCheck.id !== id) {
        return res.status(409).json({ success: false, error: `Hive Code ${data.hiveCode} is already in use.` });
      }
    }

    const updated = await prisma.hive.update({
      where: { id },
      data: {
        ...(data.name ? { name: data.name.trim() } : {}),
        ...(data.hiveCode ? { hiveCode: data.hiveCode.trim() } : {}),
        ...(data.apiaryLocation ? { apiaryLocation: data.apiaryLocation } : {}),
        ...(data.hiveType ? { hiveType: data.hiveType } : {}),
        ...(data.dateAdded ? { dateAdded: new Date(data.dateAdded) } : {}),
        ...(data.queenStatus ? { queenStatus: data.queenStatus } : {}),
        ...(data.totalFrames !== undefined ? { totalFrames: Number(data.totalFrames) } : {}),
        ...(data.broodFrames !== undefined ? { broodFrames: Number(data.broodFrames) } : {}),
        ...(data.colonyStrength ? { colonyStrength: data.colonyStrength } : {}),
        ...(data.queenAgeMonths !== undefined ? { queenAgeMonths: Number(data.queenAgeMonths) } : {}),
        ...(data.beeBreed ? { beeBreed: data.beeBreed } : {}),
        ...(data.expectedProductionKg !== undefined ? { expectedProductionKg: Number(data.expectedProductionKg) } : {}),
        ...(data.previousYearProductionKg !== undefined ? { previousYearProductionKg: Number(data.previousYearProductionKg) } : {}),
        ...(data.currentYearProductionKg !== undefined ? { currentYearProductionKg: Number(data.currentYearProductionKg) } : {}),
        ...(data.honeyType ? { honeyType: data.honeyType } : {}),
        ...(data.lastInspectionDate ? { lastInspectionDate: new Date(data.lastInspectionDate) } : {}),
        ...(data.miteStatus ? { miteStatus: data.miteStatus } : {}),
        ...(data.diseaseStatus ? { diseaseStatus: data.diseaseStatus } : {}),
        ...(data.feedingRequired !== undefined ? { feedingRequired: Boolean(data.feedingRequired) } : {}),
        ...(data.queenCondition ? { queenCondition: data.queenCondition } : {}),
        ...(data.overallHealth ? { overallHealth: data.overallHealth } : {}),
        ...(data.notes !== undefined ? { notes: data.notes } : {}),
      }
    });

    res.json({
      id: updated.id,
      userId: updated.userId,
      name: updated.name,
      hiveCode: updated.hiveCode,
      apiaryLocation: updated.apiaryLocation,
      hiveType: updated.hiveType,
      dateAdded: updated.dateAdded.toISOString(),
      queenStatus: updated.queenStatus,
      totalFrames: updated.totalFrames,
      broodFrames: updated.broodFrames,
      colonyStrength: updated.colonyStrength,
      queenAgeMonths: updated.queenAgeMonths,
      beeBreed: updated.beeBreed,
      expectedProductionKg: updated.expectedProductionKg,
      previousYearProductionKg: updated.previousYearProductionKg,
      currentYearProductionKg: updated.currentYearProductionKg,
      honeyType: updated.honeyType,
      lastInspectionDate: updated.lastInspectionDate.toISOString(),
      miteStatus: updated.miteStatus,
      diseaseStatus: updated.diseaseStatus,
      feedingRequired: updated.feedingRequired,
      queenCondition: updated.queenCondition,
      overallHealth: updated.overallHealth,
      notes: updated.notes || '',
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * DELETE /api/hives/:id
 * Delete a Hive from PostgreSQL
 */
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const existing = await prisma.hive.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: 'Hive not found' });
    }

    await prisma.hive.delete({ where: { id } });
    res.json({ success: true, message: 'Hive deleted successfully' });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;

