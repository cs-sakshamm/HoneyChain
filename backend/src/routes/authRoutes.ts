import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';

const router = Router();
const prisma = new PrismaClient();

// Helper to issue unique collision-resistant ID
function issueUniqueCode(prefix: string, bytes: number = 4): string {
  const hex = crypto.randomBytes(bytes).toString('hex').toUpperCase();
  return `${prefix}-2026-${hex}`;
}

// Helper to generate unique collision-resistant Beekeeper ID (BKR-XXXXXX)
export async function generateUniqueBeekeeperId(): Promise<string> {
  let isTaken = true;
  let code = '';
  while (isTaken) {
    const hex = crypto.randomBytes(3).toString('hex').toUpperCase();
    code = `BKR-${hex}`;
    const found = await prisma.user.findUnique({ where: { beekeeperId: code } });
    if (!found) {
      isTaken = false;
    }
  }
  return code;
}

/**
 * POST /api/auth/register
 * Register a new user account in PostgreSQL
 */
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { name, email, phone, password, role } = req.body;
    if (!name || (!email && !phone)) {
      return res.status(400).json({ success: false, error: 'Name and email or phone are required.' });
    }

    const cleanEmail = (email || `${phone.replace(/[^0-9]/g, '')}@honeychain.io`).trim().toLowerCase();
    const existing = await prisma.user.findFirst({
      where: {
        OR: [
          { email: cleanEmail },
          ...(phone ? [{ phone: phone.trim() }] : [])
        ]
      }
    });

    if (existing) {
      return res.status(409).json({ success: false, error: 'An account with this email or phone already exists.' });
    }

    const passwordHash = password ? crypto.createHash('sha256').update(password).digest('hex') : null;
    const beekeeperId = await generateUniqueBeekeeperId();

    const user = await prisma.user.create({
      data: {
        name: name.trim(),
        email: cleanEmail,
        phone: phone ? phone.trim() : null,
        passwordHash,
        role: role || 'HARVESTER',
        beekeeperId,
      }
    });

    res.status(201).json({
      success: true,
      message: 'Account registered successfully.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/auth/login
 * Authenticate existing user with email/phone & password
 */
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { emailOrPhone, password } = req.body;
    if (!emailOrPhone) {
      return res.status(400).json({ success: false, error: 'Email or phone number is required.' });
    }

    const cleanIdentifier = emailOrPhone.trim();
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: cleanIdentifier.toLowerCase() },
          { phone: cleanIdentifier }
        ]
      }
    });

    if (!user) {
      // Return 404 or create demo session if in development
      return res.status(401).json({ success: false, error: 'Invalid credentials. User not found.' });
    }

    if (user.passwordHash && password) {
      const inputHash = crypto.createHash('sha256').update(password).digest('hex');
      if (user.passwordHash !== inputHash) {
        return res.status(401).json({ success: false, error: 'Invalid password. Please try again.' });
      }
    }

    if (!user.beekeeperId) {
      const beekeeperId = await generateUniqueBeekeeperId();
      user = await prisma.user.update({
        where: { id: user.id },
        data: { beekeeperId }
      });
    }

    res.json({
      success: true,
      message: 'Authentication successful.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

import { isUserProfileComplete, normalizeUserRole } from '../services/profileService';

/**
 * GET /api/profile
 * GET /api/profile/:userId
 * Retrieve profile information and Harvester Identity (BSID / BSP)
 */
router.get('/profile', async (req: Request, res: Response) => {
  try {
    const userId = (req.query.userId as string) || (req.query.id as string);
    const roleParam = req.query.role as string;
    let user;

    if (userId) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { id: userId },
            { name: userId },
            { email: userId }
          ]
        }
      });
    }

    if (!user && roleParam) {
      const normalizedRole = normalizeUserRole(roleParam);
      user = await prisma.user.findFirst({
        where: { role: normalizedRole },
        orderBy: { createdAt: 'asc' }
      });
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'USER_NOT_FOUND',
        message: 'User profile not found.'
      });
    }

    if (!user.beekeeperId) {
      const beekeeperId = await generateUniqueBeekeeperId();
      user = await prisma.user.update({
        where: { id: user.id },
        data: { beekeeperId }
      });
    }

    const isComplete = isUserProfileComplete(user);

    res.json({
      success: true,
      profile: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        role: user.role,
        organizationName: user.organizationName || null,
        facilityLocation: user.facilityLocation || null,
        licenseNumber: user.licenseNumber || null,
        designation: user.designation || null,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        isProfileComplete: isComplete
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * PUT /api/profile
 * Update profile details (name, email, phone, organization, location, license, role)
 */
router.put('/profile', async (req: Request, res: Response) => {
  try {
    const {
      userId,
      name,
      email,
      phone,
      role,
      organizationName,
      facilityLocation,
      licenseNumber,
      designation
    } = req.body;

    let user;
    if (userId) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { id: userId },
            { name: userId },
            { email: userId }
          ]
        }
      });
    }

    if (!user && role) {
      const normalizedRole = normalizeUserRole(role);
      user = await prisma.user.findFirst({
        where: { role: normalizedRole },
        orderBy: { createdAt: 'asc' }
      });
    }

    if (!user) {
      user = await prisma.user.findFirst({
        where: { role: 'HARVESTER' },
        orderBy: { createdAt: 'asc' }
      });
    }

    if (!user) {
      return res.status(404).json({ success: false, error: 'User profile not found.' });
    }

    const updateData: any = {};
    if (name !== undefined) updateData.name = name.trim();
    if (email !== undefined) updateData.email = email.trim().toLowerCase();
    if (phone !== undefined) updateData.phone = phone.trim();
    if (role !== undefined) updateData.role = normalizeUserRole(role);
    if (organizationName !== undefined) updateData.organizationName = organizationName.trim();
    if (facilityLocation !== undefined) updateData.facilityLocation = facilityLocation.trim();
    if (licenseNumber !== undefined) updateData.licenseNumber = licenseNumber.trim();
    if (designation !== undefined) updateData.designation = designation.trim();

    if (!user.beekeeperId) {
      updateData.beekeeperId = await generateUniqueBeekeeperId();
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: updateData
    });

    const isComplete = isUserProfileComplete(updated);

    res.json({
      success: true,
      message: 'Profile updated successfully.',
      profile: {
        id: updated.id,
        name: updated.name,
        email: updated.email,
        phone: updated.phone,
        role: updated.role,
        organizationName: updated.organizationName || null,
        facilityLocation: updated.facilityLocation || null,
        licenseNumber: updated.licenseNumber || null,
        designation: updated.designation || null,
        beekeeperId: updated.beekeeperId,
        bsid: updated.bsid,
        bspPass: updated.bspPass,
        isProfileComplete: isComplete
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/profile/identity
 * Issue authoritative Harvester Identity (BSID + BSP Pass) in PostgreSQL
 */
router.post('/profile/identity', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    let user;

    if (userId) {
      user = await prisma.user.findUnique({ where: { id: userId } });
    }
    if (!user) {
      user = await prisma.user.findFirst({
        where: { role: 'HARVESTER' },
        orderBy: { createdAt: 'asc' }
      });
    }

    if (!user) {
      return res.status(404).json({ success: false, error: 'User profile not found.' });
    }

    if (user.bsid && user.bspPass) {
      return res.json({
        success: true,
        message: 'Identity already issued.',
        bsid: user.bsid,
        bspPass: user.bspPass
      });
    }

    const bsid = issueUniqueCode('BSID', 4);
    const bspPass = issueUniqueCode('BSP', 3);

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { bsid, bspPass }
    });

    res.json({
      success: true,
      message: 'Harvester identity issued successfully.',
      bsid: updated.bsid,
      bspPass: updated.bspPass
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;
