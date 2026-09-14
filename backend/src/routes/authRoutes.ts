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

// Helper to generate unique collision-resistant HoneyChain Beekeeper ID (HC-BK-XXXXXXXX)
export async function generateUniqueBeekeeperId(): Promise<string> {
  let isTaken = true;
  let code = '';
  while (isTaken) {
    const hex = crypto.randomBytes(4).toString('hex').toUpperCase();
    code = `HC-BK-${hex}`;
    const found = await prisma.user.findUnique({ where: { beekeeperId: code } });
    if (!found) {
      isTaken = false;
    }
  }
  return code;
}

import {
  isUserProfileComplete,
  normalizeUserRole,
  isHarvesterFullyVerified,
  isCollectorFullyVerified,
  isLabTesterFullyVerified,
  isPackagingManagerFullyVerified,
} from '../services/profileService';

/**
 * POST /api/auth/register
 * Register a new role-specific user account in PostgreSQL.
 * Composite identity: (email, role).
 */
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { name, email, phone, password, role } = req.body;
    if (!name || (!email && !phone)) {
      return res.status(400).json({ success: false, error: 'Name and email or phone are required.' });
    }

    const targetRole = normalizeUserRole(role || 'HARVESTER');
    const cleanEmail = (email || `${(phone || '').replace(/[^0-9]/g, '')}@honeychain.io`).trim().toLowerCase();
    const cleanPhone = phone ? phone.trim() : null;

    // Check if account already exists for THIS role
    const existing = await prisma.user.findFirst({
      where: {
        email: cleanEmail,
        role: targetRole,
      },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        error: `An account for role ${targetRole} with this email already exists. Please log in.`,
        code: 'ROLE_ACCOUNT_EXISTS',
      });
    }

    const passwordHash = password ? crypto.createHash('sha256').update(password).digest('hex') : null;
    const beekeeperId = targetRole === 'HARVESTER' ? await generateUniqueBeekeeperId() : null;

    const user = await prisma.user.create({
      data: {
        name: name.trim(),
        email: cleanEmail,
        phone: cleanPhone,
        passwordHash,
        role: targetRole,
        beekeeperId,
      },
    });

    res.status(201).json({
      success: true,
      message: 'Role account registered successfully.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        avatarUrl: user.avatarUrl || null,
        googlePhotoUrl: user.googlePhotoUrl || null,
        photoUrl: user.avatarUrl || user.googlePhotoUrl || null,
        authProvider: user.authProvider || 'local',
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/auth/login
 * Authenticate existing user with (email/phone, role, password)
 */
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { emailOrPhone, password, role } = req.body;
    if (!emailOrPhone) {
      return res.status(400).json({ success: false, error: 'Email or phone number is required.' });
    }

    const cleanIdentifier = emailOrPhone.trim();
    const cleanEmail = cleanIdentifier.toLowerCase();
    const targetRole = normalizeUserRole(role);

    // 1. First try to find user for the specific selected role
    let user = await prisma.user.findFirst({
      where: {
        role: targetRole,
        OR: [
          { email: cleanEmail },
          { phone: cleanIdentifier },
        ],
      },
      include: {
        harvesterVerification: true,
        collectorVerification: true,
        labVerification: true,
        packagingVerification: true,
      },
    });

    if (!user) {
      // Check if user has accounts in OTHER roles with this email
      const otherRoles = await prisma.user.findMany({
        where: {
          OR: [
            { email: cleanEmail },
            { phone: cleanIdentifier },
          ],
        },
        select: { role: true },
      });

      if (otherRoles.length > 0) {
        const availableRoleNames = otherRoles.map((r) => r.role).join(', ');
        return res.status(404).json({
          success: false,
          code: 'ROLE_ACCOUNT_NOT_FOUND',
          error: `No ${targetRole} account found for this email. You have accounts in: ${availableRoleNames}. Please register as ${targetRole} or select the correct role.`,
          existingRoles: otherRoles.map((r) => r.role),
        });
      }

      return res.status(401).json({
        success: false,
        code: 'USER_NOT_FOUND',
        error: 'Invalid credentials. User not found.',
      });
    }

    if (user.passwordHash && password) {
      const inputHash = crypto.createHash('sha256').update(password).digest('hex');
      if (user.passwordHash !== inputHash) {
        return res.status(401).json({ success: false, error: 'Invalid password. Please try again.' });
      }
    }

    if (user.role === 'HARVESTER' && !user.beekeeperId) {
      const beekeeperId = await generateUniqueBeekeeperId();
      user = await prisma.user.update({
        where: { id: user.id },
        data: { beekeeperId },
        include: {
          harvesterVerification: true,
          collectorVerification: true,
          labVerification: true,
          packagingVerification: true,
        },
      });
    }

    const isComplete = isUserProfileComplete(user);

    res.json({
      success: true,
      message: 'Authentication successful.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        organizationName: user.organizationName || null,
        facilityLocation: user.facilityLocation || null,
        licenseNumber: user.licenseNumber || null,
        designation: user.designation || null,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        avatarUrl: user.avatarUrl || null,
        googlePhotoUrl: user.googlePhotoUrl || null,
        photoUrl: user.avatarUrl || user.googlePhotoUrl || null,
        authProvider: user.authProvider || 'local',
        isProfileComplete: isComplete,
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/auth/google
 * Authenticate or register a Google user in PostgreSQL for the selected role
 */
router.post('/google', async (req: Request, res: Response) => {
  try {
    const { name, email, phone, role, photoUrl, googlePhotoUrl, avatarUrl } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, error: 'Email is required for Google authentication.' });
    }

    const targetRole = normalizeUserRole(role || 'HARVESTER');
    const cleanEmail = email.trim().toLowerCase();
    const incomingGooglePhoto = (photoUrl || googlePhotoUrl || '').trim() || null;
    const incomingAvatar = (avatarUrl || '').trim() || null;

    let user = await prisma.user.findFirst({
      where: {
        email: cleanEmail,
        role: targetRole,
      },
    });

    if (!user) {
      const beekeeperId = targetRole === 'HARVESTER' ? await generateUniqueBeekeeperId() : null;
      user = await prisma.user.create({
        data: {
          name: (name || 'Google User').trim(),
          email: cleanEmail,
          phone: phone ? phone.trim() : null,
          role: targetRole,
          beekeeperId,
          googlePhotoUrl: incomingGooglePhoto,
          avatarUrl: incomingAvatar,
          authProvider: 'google',
        },
      });
    } else {
      const updateData: any = {
        authProvider: 'google',
      };
      if (incomingGooglePhoto) {
        updateData.googlePhotoUrl = incomingGooglePhoto;
      }
      if (incomingAvatar) {
        updateData.avatarUrl = incomingAvatar;
      }
      if (name && (!user.name || user.name.toLowerCase() === 'google user' || user.name.toLowerCase() === 'unknown')) {
        updateData.name = name.trim();
      }
      if (targetRole === 'HARVESTER' && !user.beekeeperId) {
        updateData.beekeeperId = await generateUniqueBeekeeperId();
      }
      user = await prisma.user.update({
        where: { id: user.id },
        data: updateData,
      });
    }

    res.json({
      success: true,
      message: 'Google authentication successful.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        role: user.role,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        avatarUrl: user.avatarUrl || null,
        googlePhotoUrl: user.googlePhotoUrl || null,
        photoUrl: user.avatarUrl || user.googlePhotoUrl || null,
        authProvider: user.authProvider || 'google',
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/auth/accounts
 * Retrieve all role accounts registered with a given email address or phone,
 * with role-specific verification and completion status.
 */
router.get('/accounts', async (req: Request, res: Response) => {
  try {
    const emailParam = (req.query.email as string)?.trim().toLowerCase();
    const phoneParam = (req.query.phone as string)?.trim();
    const userId = req.query.userId as string;

    let targetEmail = emailParam;
    if (!targetEmail && userId) {
      const u = await prisma.user.findUnique({ where: { id: userId } });
      if (u) targetEmail = u.email;
    }

    if (!targetEmail && !phoneParam) {
      return res.status(400).json({ success: false, error: 'Email or phone query parameter is required.' });
    }

    const accounts = await prisma.user.findMany({
      where: {
        OR: [
          ...(targetEmail ? [{ email: targetEmail }] : []),
          ...(phoneParam ? [{ phone: phoneParam }] : []),
        ],
      },
      include: {
        harvesterVerification: true,
        collectorVerification: true,
        labVerification: true,
        packagingVerification: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    const rolesAvailable = ['HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB', 'PACKAGING'];

    const mappedAccounts = accounts.map((acc) => {
      let isVerified = false;
      let verificationStatus = 'Not Started';
      let completedSteps = 0;

      if (acc.role === 'HARVESTER') {
        isVerified = isHarvesterFullyVerified(acc.harvesterVerification);
        verificationStatus = acc.harvesterVerification?.verificationStatus || 'Not Started';
        if (acc.harvesterVerification?.governmentIdVerified === 'Verified') completedSteps++;
        if (acc.harvesterVerification?.mobileVerified === 'Verified') completedSteps++;
        if (acc.harvesterVerification?.registrationVerified === 'Verified') completedSteps++;
      } else if (acc.role === 'COLLECTOR_PROCESSOR') {
        isVerified = isCollectorFullyVerified(acc.collectorVerification);
        verificationStatus = acc.collectorVerification?.verificationStatus || 'Not Started';
        if (acc.collectorVerification?.mobileVerified === 'Verified') completedSteps++;
        if (acc.collectorVerification?.businessVerified === 'Verified') completedSteps++;
        if (acc.collectorVerification?.kycStatus === 'Verified') completedSteps++;
      } else if (acc.role === 'LAB') {
        isVerified = isLabTesterFullyVerified(acc.labVerification);
        verificationStatus = acc.labVerification?.verificationStatus || 'Not Started';
        if (acc.labVerification?.mobileVerified === 'Verified') completedSteps++;
        if (acc.labVerification?.labDetailsVerified === 'Verified') completedSteps++;
        if (acc.labVerification?.kycStatus === 'Verified') completedSteps++;
      } else if (acc.role === 'PACKAGING') {
        isVerified = isPackagingManagerFullyVerified(acc.packagingVerification);
        verificationStatus = acc.packagingVerification?.verificationStatus || 'Not Started';
        if (acc.packagingVerification?.mobileVerified === 'Verified') completedSteps++;
        if (acc.packagingVerification?.facilityDetailsVerified === 'Verified') completedSteps++;
        if (acc.packagingVerification?.kycStatus === 'Verified') completedSteps++;
      }

      return {
        id: acc.id,
        role: acc.role,
        email: acc.email,
        name: acc.name,
        phone: acc.phone,
        avatarUrl: acc.avatarUrl || null,
        googlePhotoUrl: acc.googlePhotoUrl || null,
        photoUrl: acc.avatarUrl || acc.googlePhotoUrl || null,
        authProvider: acc.authProvider || 'local',
        organizationName: acc.organizationName,
        facilityLocation: acc.facilityLocation,
        licenseNumber: acc.licenseNumber,
        beekeeperId: acc.beekeeperId,
        bsid: acc.bsid,
        isProfileComplete: isUserProfileComplete(acc),
        isVerified,
        verificationStatus,
        completedSteps,
        totalSteps: 3,
        createdAt: acc.createdAt,
      };
    });

    res.json({
      success: true,
      email: targetEmail,
      accounts: mappedAccounts,
      allSupportedRoles: rolesAvailable,
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/auth/switch-role
 * Switch active role account for an authenticated user.
 */
router.post('/switch-role', async (req: Request, res: Response) => {
  try {
    const { email, targetRole, createIfNotExists, name, phone } = req.body;
    if (!email || !targetRole) {
      return res.status(400).json({ success: false, error: 'Email and targetRole are required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const normalizedRole = normalizeUserRole(targetRole);

    let user = await prisma.user.findFirst({
      where: {
        email: cleanEmail,
        role: normalizedRole,
      },
      include: {
        harvesterVerification: true,
        collectorVerification: true,
        labVerification: true,
        packagingVerification: true,
      },
    });

    if (!user) {
      if (createIfNotExists) {
        const beekeeperId = normalizedRole === 'HARVESTER' ? await generateUniqueBeekeeperId() : null;
        user = await prisma.user.create({
          data: {
            name: (name || 'HoneyChain User').trim(),
            email: cleanEmail,
            phone: phone ? phone.trim() : null,
            role: normalizedRole,
            beekeeperId,
          },
          include: {
            harvesterVerification: true,
            collectorVerification: true,
            labVerification: true,
            packagingVerification: true,
          },
        });
      } else {
        return res.status(404).json({
          success: false,
          code: 'ACCOUNT_NOT_FOUND_FOR_ROLE',
          error: `No account exists for role ${normalizedRole} under ${cleanEmail}.`,
        });
      }
    }

    const isComplete = isUserProfileComplete(user);

    res.json({
      success: true,
      message: `Switched to ${normalizedRole} account.`,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        avatarUrl: user.avatarUrl || null,
        googlePhotoUrl: user.googlePhotoUrl || null,
        photoUrl: user.avatarUrl || user.googlePhotoUrl || null,
        authProvider: user.authProvider || 'local',
        organizationName: user.organizationName || null,
        facilityLocation: user.facilityLocation || null,
        licenseNumber: user.licenseNumber || null,
        designation: user.designation || null,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        isProfileComplete: isComplete,
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/profile
 * Retrieve role-scoped profile information
 */
router.get('/profile', async (req: Request, res: Response) => {
  try {
    const userId = (req.query.userId as string) || (req.query.id as string);
    const emailParam = (req.query.email as string)?.trim().toLowerCase();
    const roleParam = req.query.role as string;
    let user;

    if (userId) {
      user = await prisma.user.findUnique({
        where: { id: userId },
        include: {
          harvesterVerification: true,
          collectorVerification: true,
          labVerification: true,
          packagingVerification: true,
        },
      });
    }

    if (!user && emailParam && roleParam) {
      const normalizedRole = normalizeUserRole(roleParam);
      user = await prisma.user.findFirst({
        where: {
          email: emailParam,
          role: normalizedRole,
        },
        include: {
          harvesterVerification: true,
          collectorVerification: true,
          labVerification: true,
          packagingVerification: true,
        },
      });
    }

    if (!user && roleParam) {
      const normalizedRole = normalizeUserRole(roleParam);
      user = await prisma.user.findFirst({
        where: { role: normalizedRole },
        include: {
          harvesterVerification: true,
          collectorVerification: true,
          labVerification: true,
          packagingVerification: true,
        },
        orderBy: { createdAt: 'asc' },
      });
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'USER_NOT_FOUND',
        message: 'User profile not found.',
      });
    }

    if (user.role === 'HARVESTER' && !user.beekeeperId) {
      const beekeeperId = await generateUniqueBeekeeperId();
      user = await prisma.user.update({
        where: { id: user.id },
        data: { beekeeperId },
        include: {
          harvesterVerification: true,
          collectorVerification: true,
          labVerification: true,
          packagingVerification: true,
        },
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
        avatarUrl: user.avatarUrl || null,
        googlePhotoUrl: user.googlePhotoUrl || null,
        photoUrl: user.avatarUrl || user.googlePhotoUrl || null,
        authProvider: user.authProvider || 'local',
        organizationName: user.organizationName || null,
        facilityLocation: user.facilityLocation || null,
        licenseNumber: user.licenseNumber || null,
        designation: user.designation || null,
        beekeeperId: user.beekeeperId,
        bsid: user.bsid,
        bspPass: user.bspPass,
        isProfileComplete: isComplete,
        harvesterVerification: user.harvesterVerification,
        collectorVerification: user.collectorVerification,
        labVerification: user.labVerification,
        packagingVerification: user.packagingVerification,
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * PUT /api/profile
 * Update role-scoped profile details
 */
router.put('/profile', async (req: Request, res: Response) => {
  try {
    const {
      userId,
      email,
      name,
      phone,
      role,
      avatarUrl,
      organizationName,
      facilityLocation,
      licenseNumber,
      designation,
    } = req.body;

    let user;
    if (userId) {
      user = await prisma.user.findUnique({ where: { id: userId } });
    }

    if (!user && email && role) {
      user = await prisma.user.findFirst({
        where: {
          email: email.trim().toLowerCase(),
          role: normalizeUserRole(role),
        },
      });
    }

    if (!user && role) {
      user = await prisma.user.findFirst({
        where: { role: normalizeUserRole(role) },
        orderBy: { createdAt: 'asc' },
      });
    }

    if (!user) {
      return res.status(404).json({ success: false, error: 'User profile not found.' });
    }

    const updateData: any = {};
    if (name !== undefined) updateData.name = name.trim();
    if (phone !== undefined) updateData.phone = phone.trim();
    if (organizationName !== undefined) updateData.organizationName = organizationName.trim();
    if (facilityLocation !== undefined) updateData.facilityLocation = facilityLocation.trim();
    if (licenseNumber !== undefined) updateData.licenseNumber = licenseNumber.trim();
    if (designation !== undefined) updateData.designation = designation.trim();
    if (avatarUrl !== undefined) {
      updateData.avatarUrl = (avatarUrl && avatarUrl.trim()) ? avatarUrl.trim() : null;
    }

    if (user.role === 'HARVESTER' && !user.beekeeperId) {
      updateData.beekeeperId = await generateUniqueBeekeeperId();
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: updateData,
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
        avatarUrl: updated.avatarUrl || null,
        googlePhotoUrl: updated.googlePhotoUrl || null,
        photoUrl: updated.avatarUrl || updated.googlePhotoUrl || null,
        authProvider: updated.authProvider || 'local',
        organizationName: updated.organizationName || null,
        facilityLocation: updated.facilityLocation || null,
        licenseNumber: updated.licenseNumber || null,
        designation: updated.designation || null,
        beekeeperId: updated.beekeeperId,
        bsid: updated.bsid,
        bspPass: updated.bspPass,
        isProfileComplete: isComplete,
      },
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
        orderBy: { createdAt: 'asc' },
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
        bspPass: user.bspPass,
      });
    }

    const bsid = issueUniqueCode('BSID', 4);
    const bspPass = issueUniqueCode('BSP', 3);

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { bsid, bspPass },
    });

    res.json({
      success: true,
      message: 'Harvester identity issued successfully.',
      bsid: updated.bsid,
      bspPass: updated.bspPass,
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;
