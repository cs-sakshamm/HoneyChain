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
exports.otpService = exports.OtpService = void 0;
const client_1 = require("@prisma/client");
const crypto = __importStar(require("crypto"));
const prisma = new client_1.PrismaClient();
const OTP_EXPIRY_MINUTES = 5;
const OTP_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 3;
class OtpService {
    /**
     * Hash OTP with SHA-256
     */
    hashOtp(otp) {
        return crypto.createHash('sha256').update(otp).digest('hex');
    }
    /**
     * Sanitize mobile number format
     */
    sanitizeMobile(mobile) {
        return mobile.replace(/[^0-9+]/g, '').trim();
    }
    /**
     * Send / Generate OTP for mobile verification
     */
    sendOtp(mobileRaw) {
        return __awaiter(this, void 0, void 0, function* () {
            const mobile = this.sanitizeMobile(mobileRaw);
            if (!mobile || mobile.length < 8) {
                return {
                    success: false,
                    message: 'Invalid mobile number format. Please provide a valid phone number.',
                    cooldownSeconds: 0,
                    expiresInSeconds: 0
                };
            }
            const now = new Date();
            // Check existing active cooldown
            const existingOtp = yield prisma.mobileOtp.findFirst({
                where: {
                    mobile,
                    cooldownUntil: { gt: now }
                },
                orderBy: { createdAt: 'desc' }
            });
            if (existingOtp) {
                const remainingCooldown = Math.max(0, Math.ceil((existingOtp.cooldownUntil.getTime() - now.getTime()) / 1000));
                return {
                    success: false,
                    message: `Please wait ${remainingCooldown}s before requesting a new OTP.`,
                    cooldownSeconds: remainingCooldown,
                    expiresInSeconds: Math.max(0, Math.ceil((existingOtp.expiresAt.getTime() - now.getTime()) / 1000))
                };
            }
            // Generate cryptographically secure 6-digit OTP
            const rawOtp = crypto.randomInt(100000, 999999).toString();
            const otpHash = this.hashOtp(rawOtp);
            const expiresAt = new Date(now.getTime() + OTP_EXPIRY_MINUTES * 60 * 1000);
            const cooldownUntil = new Date(now.getTime() + OTP_COOLDOWN_SECONDS * 1000);
            // Invalidate old unverified OTPs for this number
            yield prisma.mobileOtp.deleteMany({
                where: {
                    mobile,
                    verified: false
                }
            });
            // Store new hashed OTP
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
            console.log(`[OTP Service] OTP generated for ${mobile}: [${rawOtp}] (Expires in ${OTP_EXPIRY_MINUTES}m)`);
            return {
                success: true,
                message: `Verification code sent to ${mobile}. Valid for ${OTP_EXPIRY_MINUTES} minutes.`,
                cooldownSeconds: OTP_COOLDOWN_SECONDS,
                expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
                devOtp: rawOtp // Useful for developer / demo verification environment
            };
        });
    }
    /**
     * Verify entered OTP
     */
    verifyOtp(mobileRaw, enteredOtp) {
        return __awaiter(this, void 0, void 0, function* () {
            const mobile = this.sanitizeMobile(mobileRaw);
            const cleanOtp = (enteredOtp || '').trim();
            if (!mobile || cleanOtp.length !== 6) {
                return {
                    success: false,
                    message: 'Please enter a valid 6-digit verification code.'
                };
            }
            const now = new Date();
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
                    message: 'No active verification code found for this mobile number. Please request a new code.'
                };
            }
            if (otpRecord.expiresAt < now) {
                return {
                    success: false,
                    message: 'Verification code has expired. Please request a new code.'
                };
            }
            if (otpRecord.attempts >= MAX_ATTEMPTS) {
                return {
                    success: false,
                    message: 'Too many incorrect attempts. This code is invalidated. Please request a new code.'
                };
            }
            const hashedInput = this.hashOtp(cleanOtp);
            if (hashedInput !== otpRecord.otpHash) {
                const remaining = MAX_ATTEMPTS - (otpRecord.attempts + 1);
                yield prisma.mobileOtp.update({
                    where: { id: otpRecord.id },
                    data: { attempts: { increment: 1 } }
                });
                return {
                    success: false,
                    message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated.'}`
                };
            }
            // Mark as verified
            yield prisma.mobileOtp.update({
                where: { id: otpRecord.id },
                data: { verified: true }
            });
            return {
                success: true,
                message: 'Mobile number verified successfully.'
            };
        });
    }
}
exports.OtpService = OtpService;
exports.otpService = new OtpService();
