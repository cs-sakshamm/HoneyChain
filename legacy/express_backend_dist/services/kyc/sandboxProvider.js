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
exports.SandboxAadhaarProvider = void 0;
const crypto = __importStar(require("crypto"));
class SandboxAadhaarProvider {
    constructor() {
        this.providerName = 'UIDAI Sandbox / Simulated Provider';
        this.isConfigured = true;
        this.isSandbox = true;
        // In-memory active session store for sandbox testing
        this.sessions = new Map();
    }
    hashOtp(otp) {
        return crypto.createHash('sha256').update(otp).digest('hex');
    }
    initiateAadhaarOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
            if (!cleanAadhaar || cleanAadhaar.length !== 12 || !/^\d{12}$/.test(cleanAadhaar)) {
                throw new Error('Please enter a valid 12-digit Aadhaar number.');
            }
            const now = new Date();
            const sessionKey = `aadhaar:${cleanAadhaar}`;
            // Check rate limit / cooldown
            const existing = this.sessions.get(sessionKey);
            if (existing && existing.cooldownUntil > now) {
                const remainingSeconds = Math.max(0, Math.ceil((existing.cooldownUntil.getTime() - now.getTime()) / 1000));
                return {
                    success: false,
                    transactionId: existing.transactionId,
                    message: `Please wait ${remainingSeconds}s before requesting a new Aadhaar OTP.`,
                    cooldownSeconds: remainingSeconds,
                    expiresInSeconds: Math.max(0, Math.ceil((existing.expiresAt.getTime() - now.getTime()) / 1000)),
                    providerName: this.providerName
                };
            }
            // Generate cryptographically secure 6-digit challenge OTP
            const rawOtp = crypto.randomInt(100000, 999999).toString();
            const otpHash = this.hashOtp(rawOtp);
            const transactionId = `TXN-UIDAI-SBX-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;
            const expiresInSeconds = 300; // 5 minutes
            const cooldownSeconds = process.env.NODE_ENV === 'production' ? 60 : 5;
            const session = {
                transactionId,
                harvesterId: request.harvesterId,
                aadhaarNumber: cleanAadhaar,
                otpHash,
                rawOtp,
                expiresAt: new Date(now.getTime() + expiresInSeconds * 1000),
                cooldownUntil: new Date(now.getTime() + cooldownSeconds * 1000),
                attempts: 0,
                verified: false
            };
            this.sessions.set(sessionKey, session);
            this.sessions.set(transactionId, session);
            const isDev = process.env.NODE_ENV !== 'production';
            if (isDev) {
                console.log(`[Aadhaar Sandbox Provider] UIDAI OTP for AADHAAR-***${cleanAadhaar.slice(-4)}: [${rawOtp}] (Txn: ${transactionId})`);
            }
            return Object.assign({ success: true, transactionId, message: 'OTP sent to your Aadhaar-linked mobile number.', cooldownSeconds,
                expiresInSeconds, providerName: this.providerName }, (isDev ? { devOtp: rawOtp } : {}));
        });
    }
    verifyAadhaarOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
            const cleanOtp = (request.otp || '').trim();
            if (!cleanOtp || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
                throw new Error('Please enter a valid 6-digit numeric OTP.');
            }
            let session;
            if (request.transactionId && this.sessions.has(request.transactionId)) {
                session = this.sessions.get(request.transactionId);
            }
            else if (cleanAadhaar && this.sessions.has(`aadhaar:${cleanAadhaar}`)) {
                session = this.sessions.get(`aadhaar:${cleanAadhaar}`);
            }
            if (!session) {
                throw new Error('No active Aadhaar verification session found. Please request a new OTP.');
            }
            const now = new Date();
            if (session.expiresAt < now) {
                throw new Error('Aadhaar verification OTP has expired. Please request a new OTP.');
            }
            if (session.attempts >= 3) {
                throw new Error('Too many incorrect OTP attempts. Session has been invalidated. Please request a new OTP.');
            }
            const inputHash = this.hashOtp(cleanOtp);
            if (inputHash !== session.otpHash) {
                session.attempts += 1;
                const remaining = 3 - session.attempts;
                throw new Error(`Incorrect Aadhaar OTP. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Session invalidated due to too many failed attempts.'}`);
            }
            session.verified = true;
            const last4 = session.aadhaarNumber.slice(-4);
            const maskedAadhaar = `AADHAAR-***${last4}`;
            const docHash = crypto.createHash('sha256').update(session.aadhaarNumber).digest('hex');
            return {
                success: true,
                verified: true,
                maskedAadhaar,
                docHash,
                providerName: this.providerName,
                transactionId: session.transactionId,
                referenceId: `REF-${session.transactionId}`,
                kycData: {
                    state: 'Verified',
                    pincode: 'Verified'
                },
                message: 'Aadhaar Verified ✓'
            };
        });
    }
}
exports.SandboxAadhaarProvider = SandboxAadhaarProvider;
