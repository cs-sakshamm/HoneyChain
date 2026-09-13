import * as crypto from 'crypto';
import {
  IAadhaarKycProvider,
  AadhaarOtpInitiateRequest,
  AadhaarOtpInitiateResponse,
  AadhaarOtpVerifyRequest,
  AadhaarOtpVerifyResponse
} from './types';

export class DigiOAadhaarProvider implements IAadhaarKycProvider {
  public readonly providerName = 'DigiO (UIDAI-Authorized KYC Provider)';
  public readonly isSandbox: boolean;

  private clientId?: string;
  private clientSecret?: string;
  private baseUrl: string;

  constructor() {
    this.clientId = process.env.AADHAAR_CLIENT_ID || process.env.DIGIO_CLIENT_ID;
    this.clientSecret = process.env.AADHAAR_API_SECRET || process.env.DIGIO_CLIENT_SECRET;
    this.isSandbox = process.env.AADHAAR_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
    this.baseUrl = process.env.AADHAAR_BASE_URL || (this.isSandbox ? 'https://ext.digio.in:444/v2' : 'https://api.digio.in/v2');
  }

  public get isConfigured(): boolean {
    return Boolean(this.clientId && this.clientSecret);
  }

  private getBasicAuthHeader(): string {
    return 'Basic ' + Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
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
      const response = await fetch(`${this.baseUrl}/client/kyc/v2/aadhaar/otp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.getBasicAuthHeader()
        },
        body: JSON.stringify({
          aadhaar_id: cleanAadhaar,
          customer_identifier: request.harvesterId
        })
      });

      const data: any = await response.json();
      if (!response.ok || !data?.id) {
        throw new Error(data?.message || data?.error_details?.message || 'DigiO Aadhaar OTP request failed.');
      }

      return {
        success: true,
        transactionId: data.id || `DIGIO-TXN-${Date.now()}`,
        message: 'OTP sent to your Aadhaar-linked mobile number.',
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to communicate with DigiO Aadhaar provider.');
    }
  }

  async verifyAadhaarOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse> {
    if (!this.isConfigured) {
      throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
    }

    const cleanAadhaar = (request.aadhaarNumber || '').replace(/\s+/g, '').trim();
    const cleanOtp = (request.otp || '').trim();

    try {
      const response = await fetch(`${this.baseUrl}/client/kyc/v2/aadhaar/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.getBasicAuthHeader()
        },
        body: JSON.stringify({
          id: request.transactionId,
          otp: cleanOtp
        })
      });

      const data: any = await response.json();
      if (!response.ok || data?.status !== 'SUCCESS') {
        throw new Error(data?.message || data?.error_details?.message || 'DigiO Aadhaar OTP validation failed.');
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
        referenceId: data.reference_id,
        kycData: {
          name: data.details?.name,
          gender: data.details?.gender,
          dob: data.details?.dob,
          careOf: data.details?.care_of,
          address: data.details?.address,
          state: data.details?.state,
          pincode: data.details?.pincode
        },
        message: 'Aadhaar Verified ✓'
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to verify OTP with DigiO Aadhaar provider.');
    }
  }
}
