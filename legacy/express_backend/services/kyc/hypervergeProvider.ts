import * as crypto from 'crypto';
import {
  IAadhaarKycProvider,
  AadhaarOtpInitiateRequest,
  AadhaarOtpInitiateResponse,
  AadhaarOtpVerifyRequest,
  AadhaarOtpVerifyResponse
} from './types';

export class HyperVergeAadhaarProvider implements IAadhaarKycProvider {
  public readonly providerName = 'HyperVerge (UIDAI-Authorized KYC Provider)';
  public readonly isSandbox: boolean;

  private appId?: string;
  private appKey?: string;
  private baseUrl: string;

  constructor() {
    this.appId = process.env.AADHAAR_API_KEY || process.env.HYPERVERGE_APP_ID;
    this.appKey = process.env.AADHAAR_API_SECRET || process.env.HYPERVERGE_APP_KEY;
    this.isSandbox = process.env.AADHAAR_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
    this.baseUrl = process.env.AADHAAR_BASE_URL || (this.isSandbox ? 'https://ind-test.idv.hyperverge.co/v1' : 'https://ind.idv.hyperverge.co/v1');
  }

  public get isConfigured(): boolean {
    return Boolean(this.appId && this.appKey);
  }

  async initiateAadhaarOtp(request: AadhaarOtpInitiateRequest): Promise<AadhaarOtpInitiateResponse> {
    if (!this.isConfigured) {
      throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
    }

    const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
    if (!cleanAadhaar || cleanAadhaar.length !== 12 || !/^\d{12}$/.test(cleanAadhaar)) {
      throw new Error('Please enter a valid 12-digit Aadhaar number.');
    }

    try {
      const response = await fetch(`${this.baseUrl}/aadhaar/generate-otp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'appId': this.appId!,
          'appKey': this.appKey!
        },
        body: JSON.stringify({
          aadhaarNumber: cleanAadhaar,
          harvesterId: request.harvesterId
        })
      });

      const data: any = await response.json();
      if (!response.ok || data?.status !== 'success') {
        throw new Error(data?.error?.message || data?.message || 'HyperVerge Aadhaar OTP request failed.');
      }

      return {
        success: true,
        transactionId: data.result?.transactionId || `HV-TXN-${Date.now()}`,
        message: 'OTP sent to your Aadhaar-linked mobile number.',
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to communicate with HyperVerge Aadhaar provider.');
    }
  }

  async verifyAadhaarOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse> {
    if (!this.isConfigured) {
      throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
    }

    const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
    const cleanOtp = (request.otp || '').trim();

    try {
      const response = await fetch(`${this.baseUrl}/aadhaar/submit-otp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'appId': this.appId!,
          'appKey': this.appKey!
        },
        body: JSON.stringify({
          transactionId: request.transactionId,
          otp: cleanOtp
        })
      });

      const data: any = await response.json();
      if (!response.ok || data?.status !== 'success') {
        throw new Error(data?.error?.message || data?.message || 'HyperVerge Aadhaar OTP validation failed.');
      }

      const last4 = cleanAadhaar.slice(-4);
      const maskedAadhaar = `AADHAAR-***${last4}`;
      const docHash = crypto.createHash('sha256').update(cleanAadhaar).digest('hex');

      return {
        success: true,
        verified: true,
        maskedAadhaar,
        docHash,
        providerName: this.providerName,
        transactionId: request.transactionId,
        referenceId: data.result?.referenceId,
        kycData: data.result?.details,
        message: 'Aadhaar Verified ✓'
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to verify OTP with HyperVerge Aadhaar provider.');
    }
  }
}
