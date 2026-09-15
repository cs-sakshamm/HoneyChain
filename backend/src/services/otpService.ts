import { SmsProviderFactory } from './sms';

export class OtpService {
  /**
   * Sanitize and normalize mobile number to standard format (+[country][number])
   * Supports standard Indian mobile numbers (10 digits -> +91XXXXXXXXXX) and international E.164
   */
  public sanitizeMobile(mobileRaw: string): string {
    if (!mobileRaw) return '';
    let cleaned = mobileRaw.replace(/[^\d+]/g, '').trim();

    // Strip leading 0 if 11 digits (e.g. 09876543210 -> 9876543210)
    if (cleaned.startsWith('0') && cleaned.length === 11) {
      cleaned = cleaned.substring(1);
    }

    // If starts with 91 and length is 12 digits (e.g. 919876543210), add +
    if (cleaned.length === 12 && cleaned.startsWith('91')) {
      cleaned = `+${cleaned}`;
    } else if (cleaned.length === 10 && /^\d{10}$/.test(cleaned)) {
      // 10-digit mobile number -> default to +91
      cleaned = `+91${cleaned}`;
    } else if (!cleaned.startsWith('+')) {
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
   * Send OTP via configured SMS Gateway (2Factor / MSG91 / Sandbox)
   */
  async sendOtp(mobileRaw: string): Promise<{
    success: boolean;
    sessionId?: string;
    message: string;
    cooldownSeconds: number;
    expiresInSeconds: number;
    devOtp?: string;
  }> {
    const mobile = this.sanitizeMobile(mobileRaw);
    if (!mobile || !this.isValidE164(mobile)) {
      return {
        success: false,
        message: 'Invalid mobile number format. Please provide a valid mobile number (e.g. +91 98765 43210).',
        cooldownSeconds: 0,
        expiresInSeconds: 0
      };
    }

    const provider = SmsProviderFactory.getProvider();
    const result = await provider.sendOtp(mobile);
    return result;
  }

  /**
   * Verify entered OTP via configured SMS Gateway
   */
  async verifyOtp(mobileRaw: string, enteredOtp: string, sessionId?: string): Promise<{
    success: boolean;
    message: string;
    sessionId?: string;
  }> {
    const mobile = this.sanitizeMobile(mobileRaw);
    const cleanOtp = (enteredOtp || '').trim();

    if (!mobile || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
      return {
        success: false,
        message: 'Please enter a valid 6-digit numeric verification code.'
      };
    }

    const provider = SmsProviderFactory.getProvider();
    const result = await provider.verifyOtp(mobile, cleanOtp, sessionId);
    return result;
  }
}

export const otpService = new OtpService();

