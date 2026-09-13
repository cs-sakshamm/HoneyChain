import * as crypto from 'crypto';
import {
  IAadhaarKycProvider,
  AadhaarOtpInitiateRequest,
  AadhaarOtpInitiateResponse,
  AadhaarOtpVerifyRequest,
  AadhaarOtpVerifyResponse
} from './types';

export class SignzyAadhaarProvider implements IAadhaarKycProvider {
  public readonly providerName = 'Signzy (UIDAI-Authorized KYC Provider)';
  public readonly isSandbox: boolean;

  private apiKey?: string;
  private apiSecret?: string;
  private baseUrl: string;

  constructor() {
    this.apiKey = process.env.AADHAAR_API_KEY || process.env.SIGNZY_API_KEY;
    this.apiSecret = process.env.AADHAAR_API_SECRET || process.env.SIGNZY_API_SECRET;
    this.isSandbox = process.env.AADHAAR_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
    this.baseUrl = process.env.AADHAAR_BASE_URL || (this.isSandbox ? 'https://preproduction.signzy.app/api/v2' : 'https://api.signzy.app/api/v2');
  }

  public get isConfigured(): boolean {
    return Boolean(this.apiKey && this.apiSecret);
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
      const response = await fetch(`${this.baseUrl}/patrons/aadhaar/otp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.apiKey!,
          'x-signzy-secret': this.apiSecret!
        },
        body: JSON.stringify({
          aadhaarNumber: cleanAadhaar,
          task: 'generateOtp'
        })
      });

      const data: any = await response.json();
      if (!response.ok || !data?.result) {
        throw new Error(data?.message || data?.error?.message || 'Signzy Aadhaar OTP dispatch failed.');
      }

      return {
        success: true,
        transactionId: data.result.requestId || `SIGNZY-${Date.now()}`,
        message: 'OTP sent to your Aadhaar-linked mobile number.',
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to communicate with Signzy Aadhaar provider.');
    }
  }

  async verifyAadhaarOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse> {
    if (!this.isConfigured) {
      throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
    }

    const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
    const cleanOtp = (request.otp || '').trim();

    try {
      const response = await fetch(`${this.baseUrl}/patrons/aadhaar/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.apiKey!,
          'x-signzy-secret': this.apiSecret!
        },
        body: JSON.stringify({
          requestId: request.transactionId,
          otp: cleanOtp
        })
      });

      const data: any = await response.json();
      if (!response.ok || !data?.result) {
        throw new Error(data?.message || data?.error?.message || 'Signzy Aadhaar OTP verification failed.');
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
        referenceId: data.result.referenceId || `SIGNZY-REF-${Date.now()}`,
        kycData: {
          name: data.result.name,
          gender: data.result.gender,
          dob: data.result.dob,
          careOf: data.result.careOf,
          address: data.result.address,
          state: data.result.state,
          pincode: data.result.pincode
        },
        message: 'Aadhaar Verified ✓'
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to verify OTP with Signzy Aadhaar provider.');
    }
  }
}
