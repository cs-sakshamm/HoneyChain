import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';
import { ISmsOtpProvider, SmsOtpSendResponse, SmsOtpVerifyResponse } from './types';

const prisma = new PrismaClient();

const OTP_EXPIRY_MINUTES = 5;
const OTP_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 3;

export class SandboxSmsProvider implements ISmsOtpProvider {
  public readonly providerName = '2Factor / SMS Testing Sandbox Provider';
  public readonly isConfigured = true;
  public readonly isSandbox = true;

  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  async sendOtp(mobile: string): Promise<SmsOtpSendResponse> {
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

    // Check active cooldown
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
        expiresInSeconds: Math.max(0, Math.ceil((existingOtp.expiresAt.getTime() - now.getTime()) / 1000)),
        providerName: this.providerName
      };
    }

    // Generate cryptographically secure 6-digit OTP
    const rawOtp = crypto.randomInt(100000, 999999).toString();
    const otpHash = this.hashOtp(rawOtp);
    const sessionId = `SESSION-2F-SBX-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;

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
      console.log(`[2Factor/SMS Sandbox] OTP dispatch to ${mobile}: [${rawOtp}] (Session: ${sessionId})`);
    }

    return {
      success: true,
      sessionId,
      message: `OTP sent to ${mobile}. Valid for ${OTP_EXPIRY_MINUTES} minutes.`,
      cooldownSeconds: OTP_COOLDOWN_SECONDS,
      expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
      providerName: this.providerName,
      ...(isDev ? { devOtp: rawOtp } : {})
    };
  }

  async verifyOtp(mobile: string, enteredOtp: string, sessionId?: string): Promise<SmsOtpVerifyResponse> {
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
      await prisma.mobileOtp.update({
        where: { id: otpRecord.id },
        data: { attempts: attemptsCount }
      });

      return {
        success: false,
        verified: false,
        message: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempt(s) remaining.` : 'Code invalidated due to too many attempts.'}`,
        providerName: this.providerName
      };
    }

    // Mark as verified
    await prisma.mobileOtp.update({
      where: { id: otpRecord.id },
      data: { verified: true }
    });

    return {
      success: true,
      verified: true,
      message: 'Mobile number verified successfully.',
      providerName: this.providerName,
      sessionId
    };
  }
}
