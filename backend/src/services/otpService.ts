import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

const OTP_EXPIRY_MINUTES = 5;
const OTP_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 3;

export class OtpService {
  /**
   * Hash OTP with SHA-256
   */
  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  /**
   * Sanitize and normalize mobile number to E.164 format (+[country][number])
   */
  public sanitizeMobile(mobileRaw: string): string {
    if (!mobileRaw) return '';
    let cleaned = mobileRaw.replace(/[^\d+]/g, '').trim();
    if (!cleaned.startsWith('+')) {
      // Default to + if not provided
      cleaned = `+${cleaned}`;
    }
    return cleaned;
  }

  /**
   * Validate E.164 compliance
   */
  public isValidE164(mobile: string): boolean {
    return /^\+[1-9]\d{7,14}$/.test(mobile);
  }

  /**
   * Send / Generate OTP for mobile verification
   */
  async sendOtp(mobileRaw: string): Promise<{
    success: boolean;
    message: string;
    cooldownSeconds: number;
    expiresInSeconds: number;
    devOtp?: string;
  }> {
    const mobile = this.sanitizeMobile(mobileRaw);
    if (!mobile || !this.isValidE164(mobile)) {
      return {
        success: false,
        message: 'Invalid mobile number format. Please provide a valid phone number in E.164 format (e.g. +1234567890).',
        cooldownSeconds: 0,
        expiresInSeconds: 0
      };
    }

    const now = new Date();

    // Check existing active cooldown
    const existingOtp = await prisma.mobileOtp.findFirst({
      where: {
        mobile,
        cooldownUntil: { gt: now }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (existingOtp) {
      const remainingCooldown = Math.max(
        0,
        Math.ceil((existingOtp.cooldownUntil.getTime() - now.getTime()) / 1000)
      );
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
    await prisma.mobileOtp.deleteMany({
      where: {
        mobile,
        verified: false
      }
    });

    // Store new hashed OTP only (never plaintext)
    await prisma.mobileOtp.create({
      data: {
        mobile,
        otpHash,
        expiresAt,
        cooldownUntil,
        attempts: 0,
        verified: false
      }
    });

    const isDev = process.env.NODE_ENV !== 'production';
    if (isDev) {
      console.log(`[OTP Service] Dev OTP generated for ${mobile.slice(0, 4)}***${mobile.slice(-2)}: [${rawOtp}] (Expires in ${OTP_EXPIRY_MINUTES}m)`);
    }

    return {
      success: true,
      message: `Verification code sent to ${mobile}. Valid for ${OTP_EXPIRY_MINUTES} minutes.`,
      cooldownSeconds: OTP_COOLDOWN_SECONDS,
      expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
      ...(isDev ? { devOtp: rawOtp } : {})
    };
  }

  /**
   * Verify entered OTP
   */
  async verifyOtp(mobileRaw: string, enteredOtp: string): Promise<{
    success: boolean;
    message: string;
  }> {
    const mobile = this.sanitizeMobile(mobileRaw);
    const cleanOtp = (enteredOtp || '').trim();

    if (!mobile || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
      return {
        success: false,
        message: 'Please enter a valid 6-digit numeric verification code.'
      };
    }

    const now = new Date();

    const otpRecord = await prisma.mobileOtp.findFirst({
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
        message: 'Too many incorrect attempts. This code has been invalidated. Please request a new code.'
      };
    }

    const hashedInput = this.hashOtp(cleanOtp);
    if (hashedInput !== otpRecord.otpHash) {
      const attemptsCount = otpRecord.attempts + 1;
      const remaining = MAX_ATTEMPTS - attemptsCount;
      await prisma.mobileOtp.update({
        where: { id: otpRecord.id },
        data: { attempts: attemptsCount }
      });

      return {
        success: false,
        message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated due to too many attempts.'}`
      };
    }

    // Mark as verified
    await prisma.mobileOtp.update({
      where: { id: otpRecord.id },
      data: { verified: true }
    });

    return {
      success: true,
      message: 'Mobile number verified successfully.'
    };
  }
}

export const otpService = new OtpService();
