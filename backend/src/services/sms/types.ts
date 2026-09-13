export interface SmsOtpSendResponse {
  success: boolean;
  sessionId?: string;
  message: string;
  cooldownSeconds: number;
  expiresInSeconds: number;
  providerName: string;
  devOtp?: string;
}

export interface SmsOtpVerifyResponse {
  success: boolean;
  verified: boolean;
  message: string;
  providerName: string;
  sessionId?: string;
}

export interface ISmsOtpProvider {
  readonly providerName: string;
  readonly isConfigured: boolean;
  readonly isSandbox: boolean;

  sendOtp(mobile: string): Promise<SmsOtpSendResponse>;
  verifyOtp(mobile: string, enteredOtp: string, sessionId?: string): Promise<SmsOtpVerifyResponse>;
}
