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
   * Sanitize mobile number format
   */
  public sanitizeMobile(mobile: string): string {
    return mobile.replace(/[^0-9+]/g, '').trim();
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

    // Store new hashed OTP
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

    console.log(`[OTP Service] OTP generated for ${mobile}: [${rawOtp}] (Expires in ${OTP_EXPIRY_MINUTES}m)`);

    return {
      success: true,
      message: `Verification code sent to ${mobile}. Valid for ${OTP_EXPIRY_MINUTES} minutes.`,
      cooldownSeconds: OTP_COOLDOWN_SECONDS,
      expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
      devOtp: rawOtp // Useful for developer / demo verification environment
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

    if (!mobile || cleanOtp.length !== 6) {
      return {
        success: false,
        message: 'Please enter a valid 6-digit verification code.'
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
        message: 'Too many incorrect attempts. This code is invalidated. Please request a new code.'
      };
    }

    const hashedInput = this.hashOtp(cleanOtp);
    if (hashedInput !== otpRecord.otpHash) {
      const remaining = MAX_ATTEMPTS - (otpRecord.attempts + 1);
      await prisma.mobileOtp.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } }
      });

      return {
        success: false,
        message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated.'}`
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
