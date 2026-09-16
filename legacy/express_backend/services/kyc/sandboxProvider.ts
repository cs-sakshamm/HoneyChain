import * as crypto from 'crypto';
import {
  IAadhaarKycProvider,
  AadhaarOtpInitiateRequest,
  AadhaarOtpInitiateResponse,
  AadhaarOtpVerifyRequest,
  AadhaarOtpVerifyResponse
} from './types';

interface SandboxSession {
  transactionId: string;
  harvesterId: string;
  aadhaarNumber: string;
  otpHash: string;
  rawOtp: string;
  expiresAt: Date;
  cooldownUntil: Date;
  attempts: number;
  verified: boolean;
}

export class SandboxAadhaarProvider implements IAadhaarKycProvider {
  public readonly providerName = 'UIDAI Sandbox / Simulated Provider';
  public readonly isConfigured = true;
  public readonly isSandbox = true;

  // In-memory active session store for sandbox testing
  private sessions: Map<string, SandboxSession> = new Map();

  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  async initiateAadhaarOtp(request: AadhaarOtpInitiateRequest): Promise<AadhaarOtpInitiateResponse> {
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
    const cooldownSeconds = 60;

    const session: SandboxSession = {
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

    return {
      success: true,
      transactionId,
      message: 'OTP sent to your Aadhaar-linked mobile number.',
      cooldownSeconds,
      expiresInSeconds,
      providerName: this.providerName,
      ...(isDev ? { devOtp: rawOtp } : {})
    };
  }

  async verifyAadhaarOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse> {
    const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
    const cleanOtp = (request.otp || '').trim();

    if (!cleanOtp || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
      throw new Error('Please enter a valid 6-digit numeric OTP.');
    }

    let session: SandboxSession | undefined;
    if (request.transactionId && this.sessions.has(request.transactionId)) {
      session = this.sessions.get(request.transactionId);
    } else if (cleanAadhaar && this.sessions.has(`aadhaar:${cleanAadhaar}`)) {
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
  }
}
