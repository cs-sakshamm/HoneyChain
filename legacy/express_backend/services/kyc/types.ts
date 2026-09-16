export interface AadhaarOtpInitiateRequest {
  harvesterId: string;
  aadhaarNumber: string;
  clientRefId?: string;
}

export interface AadhaarOtpInitiateResponse {
  success: boolean;
  transactionId: string;
  message: string;
  cooldownSeconds: number;
  expiresInSeconds: number;
  providerName: string;
  devOtp?: string;
}

export interface AadhaarOtpVerifyRequest {
  harvesterId: string;
  aadhaarNumber: string;
  transactionId?: string;
  otp: string;
}

export interface AadhaarOtpVerifyResponse {
  success: boolean;
  verified: boolean;
  maskedAadhaar: string;
  docHash: string;
  providerName: string;
  transactionId?: string;
  referenceId?: string;
  kycData?: {
    name?: string;
    gender?: string;
    dob?: string;
    careOf?: string;
    address?: string;
    state?: string;
    pincode?: string;
  };
  message: string;
}

export interface IAadhaarKycProvider {
  readonly providerName: string;
  readonly isConfigured: boolean;
  readonly isSandbox: boolean;

  initiateAadhaarOtp(request: AadhaarOtpInitiateRequest): Promise<AadhaarOtpInitiateResponse>;
  verifyAadhaarOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse>;
}
