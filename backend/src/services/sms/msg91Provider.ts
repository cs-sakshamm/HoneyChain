import { ISmsOtpProvider, SmsOtpSendResponse, SmsOtpVerifyResponse } from './types';

export class Msg91OtpProvider implements ISmsOtpProvider {
  public readonly providerName = 'MSG91 (SendOTP Gateway)';
  public readonly isSandbox: boolean;

  private authKey?: string;
  private templateId?: string;
  private baseUrl = 'https://control.msg91.com/api/v5/otp';

  constructor() {
    this.authKey = process.env.OTP_API_KEY || process.env.MSG91_AUTH_KEY;
    this.templateId = process.env.OTP_TEMPLATE_NAME || process.env.MSG91_TEMPLATE_ID;
    this.isSandbox = process.env.OTP_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
  }

  public get isConfigured(): boolean {
    return Boolean(this.authKey && this.authKey.length > 5);
  }

  async sendOtp(mobile: string): Promise<SmsOtpSendResponse> {
    if (!this.isConfigured) {
      throw new Error('SMS OTP provider credentials (MSG91) and DLT onboarding are required before production OTP dispatch can be activated.');
    }

    const cleanMobile = mobile.replace(/[^\d]/g, '');

    try {
      const url = new URL(this.baseUrl);
      url.searchParams.append('authkey', this.authKey!);
      url.searchParams.append('mobile', cleanMobile);
      if (this.templateId) {
        url.searchParams.append('template_id', this.templateId);
      }

      const response = await fetch(url.toString(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const data: any = await response.json();

      if (data?.type !== 'success') {
        throw new Error(data?.message || 'MSG91 failed to dispatch OTP.');
      }

      return {
        success: true,
        sessionId: data.request_id || `MSG91-${Date.now()}`,
        message: `OTP sent to ${mobile}. Valid for 5 minutes.`,
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to dispatch OTP via MSG91 SendOTP.');
    }
  }

  async verifyOtp(mobile: string, enteredOtp: string, sessionId?: string): Promise<SmsOtpVerifyResponse> {
    if (!this.isConfigured) {
      throw new Error('SMS OTP provider credentials (MSG91) and DLT onboarding are required before production OTP dispatch can be activated.');
    }

    const cleanMobile = mobile.replace(/[^\d]/g, '');
    const cleanOtp = enteredOtp.trim();

    try {
      const url = new URL(`${this.baseUrl}/verify`);
      url.searchParams.append('authkey', this.authKey!);
      url.searchParams.append('mobile', cleanMobile);
      url.searchParams.append('otp', cleanOtp);

      const response = await fetch(url.toString(), { method: 'GET' });
      const data: any = await response.json();

      if (data?.type === 'success' || data?.message === 'OTP verified success') {
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
        message: data?.message || 'Invalid or expired verification code.',
        providerName: this.providerName
      };
    } catch (err: any) {
      throw new Error(err?.message || 'Failed to verify OTP with MSG91.');
    }
  }
}
