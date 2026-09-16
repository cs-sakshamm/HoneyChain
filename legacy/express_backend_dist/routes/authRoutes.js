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
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateUniqueBeekeeperId = void 0;
const express_1 = require("express");
const client_1 = require("@prisma/client");
const crypto = __importStar(require("crypto"));
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
// Helper to issue unique collision-resistant ID
function issueUniqueCode(prefix, bytes = 4) {
    const hex = crypto.randomBytes(bytes).toString('hex').toUpperCase();
    return `${prefix}-2026-${hex}`;
}
// Helper to generate unique collision-resistant HoneyChain Beekeeper ID (HC-BK-XXXXXXXX)
function generateUniqueBeekeeperId() {
    return __awaiter(this, void 0, void 0, function* () {
        let isTaken = true;
        let code = '';
        while (isTaken) {
            const hex = crypto.randomBytes(4).toString('hex').toUpperCase();
            code = `HC-BK-${hex}`;
            const found = yield prisma.user.findUnique({ where: { beekeeperId: code } });
            if (!found) {
                isTaken = false;
            }
        }
        return code;
    });
}
exports.generateUniqueBeekeeperId = generateUniqueBeekeeperId;
const profileService_1 = require("../services/profileService");
/**
 * POST /api/auth/register
 * Register a new role-specific user account in PostgreSQL.
 * Composite identity: (email, role).
 */
router.post('/register', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { name, email, phone, password, role } = req.body;
        if (!name || (!email && !phone)) {
            return res.status(400).json({ success: false, error: 'Name and email or phone are required.' });
        }
        const targetRole = (0, profileService_1.normalizeUserRole)(role || 'HARVESTER');
        const cleanEmail = (email || `${(phone || '').replace(/[^0-9]/g, '')}@honeychain.io`).trim().toLowerCase();
        const cleanPhone = phone ? phone.trim() : null;
        // Check if account already exists for THIS role
        const existing = yield prisma.user.findFirst({
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
        const beekeeperId = targetRole === 'HARVESTER' ? yield generateUniqueBeekeeperId() : null;
        const user = yield prisma.user.create({
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/login
 * Authenticate existing user with (email/phone, role, password)
 */
router.post('/login', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { emailOrPhone, password, role } = req.body;
        if (!emailOrPhone) {
            return res.status(400).json({ success: false, error: 'Email or phone number is required.' });
        }
        const cleanIdentifier = emailOrPhone.trim();
        const cleanEmail = cleanIdentifier.toLowerCase();
        const targetRole = (0, profileService_1.normalizeUserRole)(role);
        // 1. First try to find user for the specific selected role
        let user = yield prisma.user.findFirst({
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
            const otherRoles = yield prisma.user.findMany({
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
            const beekeeperId = yield generateUniqueBeekeeperId();
            user = yield prisma.user.update({
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
        const isComplete = (0, profileService_1.isUserProfileComplete)(user);
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/google
 * Authenticate or register a Google user in PostgreSQL for the selected role
 */
router.post('/google', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { name, email, phone, role, photoUrl, googlePhotoUrl, avatarUrl } = req.body;
        if (!email) {
            return res.status(400).json({ success: false, error: 'Email is required for Google authentication.' });
        }
        const targetRole = (0, profileService_1.normalizeUserRole)(role || 'HARVESTER');
        const cleanEmail = email.trim().toLowerCase();
        const incomingGooglePhoto = (photoUrl || googlePhotoUrl || '').trim() || null;
        const incomingAvatar = (avatarUrl || '').trim() || null;
        let user = yield prisma.user.findFirst({
            where: {
                email: cleanEmail,
                role: targetRole,
            },
        });
        if (!user) {
            const beekeeperId = targetRole === 'HARVESTER' ? yield generateUniqueBeekeeperId() : null;
            user = yield prisma.user.create({
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
        }
        else {
            const updateData = {
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
                updateData.beekeeperId = yield generateUniqueBeekeeperId();
            }
            user = yield prisma.user.update({
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * GET /api/auth/accounts
 * Retrieve all role accounts registered with a given email address or phone,
 * with role-specific verification and completion status.
 */
router.get('/accounts', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    try {
        const emailParam = (_a = req.query.email) === null || _a === void 0 ? void 0 : _a.trim().toLowerCase();
        const phoneParam = (_b = req.query.phone) === null || _b === void 0 ? void 0 : _b.trim();
        const userId = req.query.userId;
        let targetEmail = emailParam;
        if (!targetEmail && userId) {
            const u = yield prisma.user.findUnique({ where: { id: userId } });
            if (u)
                targetEmail = u.email;
        }
        if (!targetEmail && !phoneParam) {
            return res.status(400).json({ success: false, error: 'Email or phone query parameter is required.' });
        }
        const accounts = yield prisma.user.findMany({
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
            var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r;
            let isVerified = false;
            let verificationStatus = 'Not Started';
            let completedSteps = 0;
            if (acc.role === 'HARVESTER') {
                isVerified = (0, profileService_1.isHarvesterFullyVerified)(acc.harvesterVerification);
                verificationStatus = ((_a = acc.harvesterVerification) === null || _a === void 0 ? void 0 : _a.verificationStatus) || 'Not Started';
                if (((_b = acc.harvesterVerification) === null || _b === void 0 ? void 0 : _b.governmentIdVerified) === 'Verified')
                    completedSteps++;
                if (((_c = acc.harvesterVerification) === null || _c === void 0 ? void 0 : _c.mobileVerified) === 'Verified')
                    completedSteps++;
                if (((_d = acc.harvesterVerification) === null || _d === void 0 ? void 0 : _d.registrationVerified) === 'Verified')
                    completedSteps++;
            }
            else if (acc.role === 'COLLECTOR_PROCESSOR') {
                isVerified = (0, profileService_1.isCollectorFullyVerified)(acc.collectorVerification);
                verificationStatus = ((_e = acc.collectorVerification) === null || _e === void 0 ? void 0 : _e.verificationStatus) || 'Not Started';
                if (((_f = acc.collectorVerification) === null || _f === void 0 ? void 0 : _f.mobileVerified) === 'Verified')
                    completedSteps++;
                if (((_g = acc.collectorVerification) === null || _g === void 0 ? void 0 : _g.businessVerified) === 'Verified')
                    completedSteps++;
                if (((_h = acc.collectorVerification) === null || _h === void 0 ? void 0 : _h.kycStatus) === 'Verified')
                    completedSteps++;
            }
            else if (acc.role === 'LAB') {
                isVerified = (0, profileService_1.isLabTesterFullyVerified)(acc.labVerification);
                verificationStatus = ((_j = acc.labVerification) === null || _j === void 0 ? void 0 : _j.verificationStatus) || 'Not Started';
                if (((_k = acc.labVerification) === null || _k === void 0 ? void 0 : _k.mobileVerified) === 'Verified')
                    completedSteps++;
                if (((_l = acc.labVerification) === null || _l === void 0 ? void 0 : _l.labDetailsVerified) === 'Verified')
                    completedSteps++;
                if (((_m = acc.labVerification) === null || _m === void 0 ? void 0 : _m.kycStatus) === 'Verified')
                    completedSteps++;
            }
            else if (acc.role === 'PACKAGING') {
                isVerified = (0, profileService_1.isPackagingManagerFullyVerified)(acc.packagingVerification);
                verificationStatus = ((_o = acc.packagingVerification) === null || _o === void 0 ? void 0 : _o.verificationStatus) || 'Not Started';
                if (((_p = acc.packagingVerification) === null || _p === void 0 ? void 0 : _p.mobileVerified) === 'Verified')
                    completedSteps++;
                if (((_q = acc.packagingVerification) === null || _q === void 0 ? void 0 : _q.facilityDetailsVerified) === 'Verified')
                    completedSteps++;
                if (((_r = acc.packagingVerification) === null || _r === void 0 ? void 0 : _r.kycStatus) === 'Verified')
                    completedSteps++;
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
                isProfileComplete: (0, profileService_1.isUserProfileComplete)(acc),
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/switch-role
 * Switch active role account for an authenticated user.
 */
router.post('/switch-role', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { email, targetRole, createIfNotExists, name, phone } = req.body;
        if (!email || !targetRole) {
            return res.status(400).json({ success: false, error: 'Email and targetRole are required.' });
        }
        const cleanEmail = email.trim().toLowerCase();
        const normalizedRole = (0, profileService_1.normalizeUserRole)(targetRole);
        let user = yield prisma.user.findFirst({
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
                const beekeeperId = normalizedRole === 'HARVESTER' ? yield generateUniqueBeekeeperId() : null;
                user = yield prisma.user.create({
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
            }
            else {
                return res.status(404).json({
                    success: false,
                    code: 'ACCOUNT_NOT_FOUND_FOR_ROLE',
                    error: `No account exists for role ${normalizedRole} under ${cleanEmail}.`,
                });
            }
        }
        const isComplete = (0, profileService_1.isUserProfileComplete)(user);
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * GET /api/profile
 * Retrieve role-scoped profile information
 */
router.get('/profile', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _c;
    try {
        const userId = req.query.userId || req.query.id;
        const emailParam = (_c = req.query.email) === null || _c === void 0 ? void 0 : _c.trim().toLowerCase();
        const roleParam = req.query.role;
        let user;
        if (userId) {
            user = yield prisma.user.findUnique({
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
            const normalizedRole = (0, profileService_1.normalizeUserRole)(roleParam);
            user = yield prisma.user.findFirst({
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
            const normalizedRole = (0, profileService_1.normalizeUserRole)(roleParam);
            user = yield prisma.user.findFirst({
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
            const beekeeperId = yield generateUniqueBeekeeperId();
            user = yield prisma.user.update({
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
        const isComplete = (0, profileService_1.isUserProfileComplete)(user);
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * PUT /api/profile
 * Update role-scoped profile details
 */
router.put('/profile', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, email, name, phone, role, avatarUrl, organizationName, facilityLocation, licenseNumber, designation, } = req.body;
        let user;
        if (userId) {
            user = yield prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user && email && role) {
            user = yield prisma.user.findFirst({
                where: {
                    email: email.trim().toLowerCase(),
                    role: (0, profileService_1.normalizeUserRole)(role),
                },
            });
        }
        if (!user && role) {
            user = yield prisma.user.findFirst({
                where: { role: (0, profileService_1.normalizeUserRole)(role) },
                orderBy: { createdAt: 'asc' },
            });
        }
        if (!user) {
            return res.status(404).json({ success: false, error: 'User profile not found.' });
        }
        const updateData = {};
        if (name !== undefined)
            updateData.name = name.trim();
        if (phone !== undefined)
            updateData.phone = phone.trim();
        if (organizationName !== undefined)
            updateData.organizationName = organizationName.trim();
        if (facilityLocation !== undefined)
            updateData.facilityLocation = facilityLocation.trim();
        if (licenseNumber !== undefined)
            updateData.licenseNumber = licenseNumber.trim();
        if (designation !== undefined)
            updateData.designation = designation.trim();
        if (avatarUrl !== undefined) {
            updateData.avatarUrl = (avatarUrl && avatarUrl.trim()) ? avatarUrl.trim() : null;
        }
        if (user.role === 'HARVESTER' && !user.beekeeperId) {
            updateData.beekeeperId = yield generateUniqueBeekeeperId();
        }
        const updated = yield prisma.user.update({
            where: { id: user.id },
            data: updateData,
        });
        const isComplete = (0, profileService_1.isUserProfileComplete)(updated);
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
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/profile/identity
 * Issue authoritative Harvester Identity (BSID + BSP Pass) in PostgreSQL
 */
router.post('/profile/identity', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId } = req.body;
        let user;
        if (userId) {
            user = yield prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user) {
            user = yield prisma.user.findFirst({
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
        const updated = yield prisma.user.update({
            where: { id: user.id },
            data: { bsid, bspPass },
        });
        res.json({
            success: true,
            message: 'Harvester identity issued successfully.',
            bsid: updated.bsid,
            bspPass: updated.bspPass,
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/forgot-password
 * Issue password reset email
 */
router.post('/forgot-password', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { email } = req.body;
        if (!email) {
            return res.status(400).json({ success: false, error: 'Email is required' });
        }
        const cleanEmail = email.trim().toLowerCase();
        const user = yield prisma.user.findFirst({ where: { email: cleanEmail } });
        if (!user) {
            // Don't leak if the user exists or not, but for demo we can return success
            return res.json({ success: true, message: 'If the email exists, a reset link was sent.' });
        }
        // In a real application, you would generate a secure reset token,
        // save it to the DB with an expiry, and send an email.
        // For now, we simulate a successful email sending.
        const resetToken = crypto.randomBytes(32).toString('hex');
        const resetExpiry = new Date(Date.now() + 3600000); // 1 hour
        yield prisma.user.update({
            where: { id: user.id },
            data: { resetToken, resetExpiry }
        });
        res.json({
            success: true,
            message: 'If the email exists, a reset link was sent.',
            devToken: resetToken // Expose for testing
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/reset-password
 * Reset user password using token
 */
router.post('/reset-password', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { token, newPassword } = req.body;
        if (!token || !newPassword) {
            return res.status(400).json({ success: false, error: 'Token and new password are required' });
        }
        const user = yield prisma.user.findFirst({
            where: {
                resetToken: token,
                resetExpiry: {
                    gt: new Date()
                }
            }
        });
        if (!user) {
            return res.status(400).json({ success: false, error: 'Invalid or expired reset token.' });
        }
        const passwordHash = crypto.createHash('sha256').update(newPassword.trim()).digest('hex');
        yield prisma.user.update({
            where: { id: user.id },
            data: {
                passwordHash,
                resetToken: null,
                resetExpiry: null
            }
        });
        res.json({
            success: true,
            message: 'Password reset successfully. You can now log in.'
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
exports.default = router;
