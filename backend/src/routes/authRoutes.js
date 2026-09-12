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
/**
 * POST /api/auth/register
 * Register a new user account in PostgreSQL
 */
router.post('/register', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { name, email, phone, password, role } = req.body;
        if (!name || (!email && !phone)) {
            return res.status(400).json({ success: false, error: 'Name and email or phone are required.' });
        }
        const cleanEmail = (email || `${phone.replace(/[^0-9]/g, '')}@honeychain.io`).trim().toLowerCase();
        const existing = yield prisma.user.findFirst({
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
        const user = yield prisma.user.create({
            data: {
                name: name.trim(),
                email: cleanEmail,
                phone: phone ? phone.trim() : null,
                passwordHash,
                role: role || 'HARVESTER'
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
                bsid: user.bsid,
                bspPass: user.bspPass
            }
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * POST /api/auth/login
 * Authenticate existing user with email/phone & password
 */
router.post('/login', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { emailOrPhone, password } = req.body;
        if (!emailOrPhone) {
            return res.status(400).json({ success: false, error: 'Email or phone number is required.' });
        }
        const cleanIdentifier = emailOrPhone.trim();
        const user = yield prisma.user.findFirst({
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
        res.json({
            success: true,
            message: 'Authentication successful.',
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                role: user.role,
                bsid: user.bsid,
                bspPass: user.bspPass
            }
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * GET /api/profile
 * GET /api/profile/:userId
 * Retrieve profile information and Harvester Identity (BSID / BSP)
 */
router.get('/profile', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const userId = req.query.userId || req.query.id;
        let user;
        if (userId) {
            user = yield prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user) {
            // Find primary harvester user or default
            user = yield prisma.user.findFirst({
                where: { role: 'HARVESTER' },
                orderBy: { createdAt: 'asc' }
            });
        }
        if (!user) {
            // Auto-create default initial harvester
            user = yield prisma.user.create({
                data: {
                    id: 'user-default-harvester',
                    name: 'HoneyChain Apiary Manager',
                    email: 'operations@honeychain.io',
                    phone: '+1 (555) 234-5678',
                    role: 'HARVESTER',
                    bsid: 'BSID-2026-A1B2C3D4',
                    bspPass: 'BSP-2026-E5F6'
                }
            });
        }
        res.json({
            success: true,
            profile: {
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone || '+1 (555) 234-5678',
                role: user.role,
                bsid: user.bsid,
                bspPass: user.bspPass
            }
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
/**
 * PUT /api/profile
 * Update profile details (name, email, phone)
 */
router.put('/profile', (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { userId, name, email, phone } = req.body;
        let user;
        if (userId) {
            user = yield prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user) {
            user = yield prisma.user.findFirst({
                where: { role: 'HARVESTER' },
                orderBy: { createdAt: 'asc' }
            });
        }
        if (!user) {
            return res.status(404).json({ success: false, error: 'User profile not found.' });
        }
        const updated = yield prisma.user.update({
            where: { id: user.id },
            data: Object.assign(Object.assign(Object.assign({}, (name ? { name: name.trim() } : {})), (email ? { email: email.trim().toLowerCase() } : {})), (phone ? { phone: phone.trim() } : {}))
        });
        res.json({
            success: true,
            message: 'Profile updated successfully.',
            profile: {
                id: updated.id,
                name: updated.name,
                email: updated.email,
                phone: updated.phone,
                role: updated.role,
                bsid: updated.bsid,
                bspPass: updated.bspPass
            }
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
        const updated = yield prisma.user.update({
            where: { id: user.id },
            data: { bsid, bspPass }
        });
        res.json({
            success: true,
            message: 'Harvester identity issued successfully.',
            bsid: updated.bsid,
            bspPass: updated.bspPass
        });
    }
    catch (error) {
        res.status(500).json({ success: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) });
    }
}));
exports.default = router;
