import { ISmsOtpProvider, SmsOtpSendResponse, SmsOtpVerifyResponse } from './types';

export class TwoFactorOtpProvider implements ISmsOtpProvider {
  public readonly providerName = '2Factor (SMS OTP Gateway)';
  public readonly isSandbox: boolean;

  private apiKey?: string;
  private senderId?: string;
  private templateName?: string;
  private baseUrl = 'https://2factor.in/API/V1';

  constructor() {
    this.apiKey = process.env.MOBILE_OTP_API_KEY || process.env.OTP_API_KEY || process.env.TWOFACTOR_API_KEY;
    this.senderId = process.env.MOBILE_OTP_SENDER_ID || process.env.OTP_SENDER_ID || process.env.TWOFACTOR_SENDER_ID || 'HNYCHN';
    this.templateName = process.env.MOBILE_OTP_TEMPLATE_NAME || process.env.OTP_TEMPLATE_NAME || process.env.TWOFACTOR_TEMPLATE_NAME;
    this.baseUrl = process.env.MOBILE_OTP_BASE_URL || 'https://2factor.in/API/V1';
    this.isSandbox = process.env.OTP_ENVIRONMENT === 'sandbox' || (process.env.NODE_ENV !== 'production' && !this.apiKey);
  }

  public get isConfigured(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5);
  }

  async sendOtp(mobile: string): Promise<SmsOtpSendResponse> {
    if (!this.isConfigured) {
      throw new Error('SMS OTP provider credentials (2Factor) and DLT onboarding are required before production OTP dispatch can be activated.');
    }

    // Clean mobile number to exactly 10 digits for 2Factor India SMS gateway
    let cleanMobile = mobile.replace(/[^\d]/g, '');
    if (cleanMobile.startsWith('91') && cleanMobile.length === 12) {
      cleanMobile = cleanMobile.substring(2);
    }
    if (cleanMobile.length !== 10) {
      throw new Error('Please enter a valid 10-digit Indian mobile number.');
    }

    try {
      const endpoint = this.templateName
        ? `${this.baseUrl}/${this.apiKey}/SMS/${cleanMobile}/AUTOGEN3/${encodeURIComponent(this.templateName)}`
        : `${this.baseUrl}/${this.apiKey}/SMS/${cleanMobile}/AUTOGEN`;

      const response = await fetch(endpoint);
      const data: any = await response.json();

      if (data?.Status !== 'Success') {
        throw new Error(data?.Details || '2Factor failed to dispatch SMS OTP.');
      }

      return {
        success: true,
        sessionId: data.Details,
        message: `OTP sent to ${mobile}. Valid for 5 minutes.`,
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to dispatch OTP via 2Factor SMS Gateway.');
    }
  }

  async verifyOtp(mobile: string, enteredOtp: string, sessionId?: string): Promise<SmsOtpVerifyResponse> {
    if (!this.isConfigured) {
      throw new Error('SMS OTP provider credentials (2Factor) and DLT onboarding are required before production OTP dispatch can be activated.');
    }

    let cleanMobile = mobile.replace(/[^\d]/g, '');
    if (cleanMobile.startsWith('91') && cleanMobile.length === 12) {
      cleanMobile = cleanMobile.substring(2);
    }
    const cleanOtp = enteredOtp.trim();

    try {
      const endpoint = sessionId
        ? `${this.baseUrl}/${this.apiKey}/SMS/VERIFY/${sessionId}/${cleanOtp}`
        : `${this.baseUrl}/${this.apiKey}/SMS/VERIFY3/${cleanMobile}/${cleanOtp}`;

      const response = await fetch(endpoint);
      const data: any = await response.json();

      if (data?.Status === 'Success' && data?.Details === 'OTP Matched') {
        return {
          success: true,
          verified: true,
          message: 'Mobile number verified successfully.',
          providerName: this.providerName,
          sessionId
        };
      }

      return {
        success: false,
        verified: false,
        message: data?.Details || 'Invalid or expired verification code.',
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to verify OTP with 2Factor SMS Gateway.');
    }
  }
}
