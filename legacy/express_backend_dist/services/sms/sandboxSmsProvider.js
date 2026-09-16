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
exports.SandboxSmsProvider = void 0;
const client_1 = require("@prisma/client");
const crypto = __importStar(require("crypto"));
const prisma = new client_1.PrismaClient();
const OTP_EXPIRY_MINUTES = 5;
const OTP_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 3;
class SandboxSmsProvider {
    constructor() {
        this.providerName = '2Factor / SMS Testing Sandbox Provider';
        this.isConfigured = true;
        this.isSandbox = true;
    }
    hashOtp(otp) {
        return crypto.createHash('sha256').update(otp).digest('hex');
    }
    sendOtp(mobile) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!mobile || !/^\+[1-9]\d{7,14}$/.test(mobile)) {
                return {
                    success: false,
                    message: 'Invalid mobile number format. Please provide a valid mobile number (e.g. +91 98765 43210).',
                    cooldownSeconds: 0,
                    expiresInSeconds: 0,
                    providerName: this.providerName
                };
            }
            const now = new Date();
            // Check active cooldown from memory store first
            const memOtp = SandboxSmsProvider.memoryStore.get(mobile);
            if (memOtp && memOtp.cooldownUntil > now && !memOtp.verified) {
                const remainingCooldown = Math.max(0, Math.ceil((memOtp.cooldownUntil.getTime() - now.getTime()) / 1000));
                return {
                    success: false,
                    message: `Please wait ${remainingCooldown}s before requesting a new OTP.`,
                    cooldownSeconds: remainingCooldown,
                    expiresInSeconds: Math.max(0, Math.ceil((memOtp.expiresAt.getTime() - now.getTime()) / 1000)),
                    providerName: this.providerName,
                    devOtp: memOtp.rawOtp
                };
            }
            // Check active cooldown from database (if accessible)
            try {
                const existingOtp = yield prisma.mobileOtp.findFirst({
                    where: {
                        mobile,
                        cooldownUntil: { gt: now },
                        verified: false
                    },
                    orderBy: { createdAt: 'desc' }
                });
                if (existingOtp) {
                    const remainingCooldown = Math.max(0, Math.ceil((existingOtp.cooldownUntil.getTime() - now.getTime()) / 1000));
                    return {
                        success: false,
                        message: `Please wait ${remainingCooldown}s before requesting a new OTP.`,
                        cooldownSeconds: remainingCooldown,
                        expiresInSeconds: Math.max(0, Math.ceil((existingOtp.expiresAt.getTime() - now.getTime()) / 1000)),
                        providerName: this.providerName,
                        devOtp: memOtp === null || memOtp === void 0 ? void 0 : memOtp.rawOtp
                    };
                }
            }
            catch (dbErr) {
                console.warn('[SandboxSmsProvider] Prisma DB offline, using in-memory store:', dbErr === null || dbErr === void 0 ? void 0 : dbErr.message);
            }
            // Generate cryptographically secure 6-digit OTP
            const rawOtp = crypto.randomInt(100000, 999999).toString();
            const otpHash = this.hashOtp(rawOtp);
            const sessionId = `SESSION-2F-SBX-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;
            const expiresAt = new Date(now.getTime() + OTP_EXPIRY_MINUTES * 60 * 1000);
            const cooldownUntil = new Date(now.getTime() + OTP_COOLDOWN_SECONDS * 1000);
            // Save to memory store
            SandboxSmsProvider.memoryStore.set(mobile, {
                otpHash,
                expiresAt,
                cooldownUntil,
                attempts: 0,
                verified: false,
                rawOtp
            });
            // Try database persistence (non-blocking)
            try {
                yield prisma.mobileOtp.deleteMany({
                    where: {
                        mobile,
                        verified: false
                    }
                });
                yield prisma.mobileOtp.create({
                    data: {
                        mobile,
                        otpHash,
                        expiresAt,
                        cooldownUntil,
                        attempts: 0,
                        verified: false
                    }
                });
            }
            catch (dbErr) {
                console.warn('[SandboxSmsProvider] Failed to persist OTP to DB, retained in memory:', dbErr === null || dbErr === void 0 ? void 0 : dbErr.message);
            }
            const isDev = process.env.NODE_ENV !== 'production';
            if (isDev) {
                console.log(`[2Factor/SMS Sandbox] OTP dispatch to ${mobile}: [${rawOtp}] (Session: ${sessionId})`);
            }
            return Object.assign({ success: true, sessionId, message: `OTP sent to ${mobile}. Valid for ${OTP_EXPIRY_MINUTES} minutes.`, cooldownSeconds: OTP_COOLDOWN_SECONDS, expiresInSeconds: OTP_EXPIRY_MINUTES * 60, providerName: this.providerName }, (isDev ? { devOtp: rawOtp } : {}));
        });
    }
    verifyOtp(mobile, enteredOtp, sessionId) {
        return __awaiter(this, void 0, void 0, function* () {
            const cleanOtp = (enteredOtp || '').trim();
            if (!mobile || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
                return {
                    success: false,
                    verified: false,
                    message: 'Please enter a valid 6-digit numeric verification code.',
                    providerName: this.providerName
                };
            }
            const now = new Date();
            const isDev = process.env.NODE_ENV !== 'production';
            // Allow master dev OTP "123456" in dev mode if needed
            if (isDev && cleanOtp === '123456') {
                const mem = SandboxSmsProvider.memoryStore.get(mobile);
                if (mem)
                    mem.verified = true;
                try {
                    yield prisma.mobileOtp.updateMany({
                        where: { mobile, verified: false },
                        data: { verified: true }
                    });
                }
                catch (_) { }
                return {
                    success: true,
                    verified: true,
                    message: 'Mobile number verified successfully (Dev Master Code).',
                    providerName: this.providerName,
                    sessionId
                };
            }
            // Check memory store
            const memOtp = SandboxSmsProvider.memoryStore.get(mobile);
            if (memOtp) {
                if (memOtp.expiresAt < now) {
                    return {
                        success: false,
                        verified: false,
                        message: 'Verification code has expired. Please request a new code.',
                        providerName: this.providerName
                    };
                }
                if (memOtp.attempts >= MAX_ATTEMPTS) {
                    return {
                        success: false,
                        verified: false,
                        message: 'Too many incorrect attempts. This code has been invalidated. Please request a new code.',
                        providerName: this.providerName
                    };
                }
                const hashedInput = this.hashOtp(cleanOtp);
                if (hashedInput === memOtp.otpHash || cleanOtp === memOtp.rawOtp) {
                    memOtp.verified = true;
                    try {
                        yield prisma.mobileOtp.updateMany({
                            where: { mobile, verified: false },
                            data: { verified: true }
                        });
                    }
                    catch (_) { }
                    return {
                        success: true,
                        verified: true,
                        message: 'Mobile number verified successfully.',
                        providerName: this.providerName,
                        sessionId
                    };
                }
                else {
                    memOtp.attempts += 1;
                    const remaining = MAX_ATTEMPTS - memOtp.attempts;
                    return {
                        success: false,
                        verified: false,
                        message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated due to too many attempts.'}`,
                        providerName: this.providerName
                    };
                }
            }
            // Check database
            try {
                const otpRecord = yield prisma.mobileOtp.findFirst({
                    where: {
                        mobile,
                        verified: false
                    },
                    orderBy: { createdAt: 'desc' }
                });
                if (!otpRecord) {
                    return {
                        success: false,
                        verified: false,
                        message: 'No active verification code found for this mobile number. Please request a new code.',
                        providerName: this.providerName
                    };
                }
                if (otpRecord.expiresAt < now) {
                    return {
                        success: false,
                        verified: false,
                        message: 'Verification code has expired. Please request a new code.',
                        providerName: this.providerName
                    };
                }
                if (otpRecord.attempts >= MAX_ATTEMPTS) {
                    return {
                        success: false,
                        verified: false,
                        message: 'Too many incorrect attempts. This code has been invalidated. Please request a new code.',
                        providerName: this.providerName
                    };
                }
                const hashedInput = this.hashOtp(cleanOtp);
                if (hashedInput !== otpRecord.otpHash) {
                    const attemptsCount = otpRecord.attempts + 1;
                    const remaining = MAX_ATTEMPTS - attemptsCount;
                    yield prisma.mobileOtp.update({
                        where: { id: otpRecord.id },
                        data: { attempts: attemptsCount }
                    }).catch(() => { });
                    return {
                        success: false,
                        verified: false,
                        message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated due to too many attempts.'}`,
                        providerName: this.providerName
                    };
                }
                // Mark as verified
                yield prisma.mobileOtp.update({
                    where: { id: otpRecord.id },
                    data: { verified: true }
                }).catch(() => { });
                return {
                    success: true,
                    verified: true,
                    message: 'Mobile number verified successfully.',
                    providerName: this.providerName,
                    sessionId
                };
            }
            catch (dbErr) {
                return {
                    success: false,
                    verified: false,
                    message: 'Database unavailable and no cached code found. Please request a new code.',
                    providerName: this.providerName
                };
            }
        });
    }
}
exports.SandboxSmsProvider = SandboxSmsProvider;
// In-memory resilient store for local testing without DB dependency
SandboxSmsProvider.memoryStore = new Map();
