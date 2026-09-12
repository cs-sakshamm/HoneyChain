import { IAadhaarKycProvider, AadhaarOtpInitiateRequest, AadhaarOtpVerifyRequest, AadhaarOtpInitiateResponse, AadhaarOtpVerifyResponse } from './types';
import { SandboxAadhaarProvider } from './sandboxProvider';
import { SignzyAadhaarProvider } from './signzyProvider';
import { HyperVergeAadhaarProvider } from './hypervergeProvider';
import { DigiOAadhaarProvider } from './digioProvider';

export type AadhaarProviderType = 'sandbox' | 'signzy' | 'hyperverge' | 'digio';

export class KycProviderFactory {
  private static cachedProvider?: IAadhaarKycProvider;
  private static currentProviderType?: string;

  public static getProvider(): IAadhaarKycProvider {
    const configuredType = (process.env.AADHAAR_PROVIDER || 'sandbox').toLowerCase().trim() as AadhaarProviderType;
    const isProduction = process.env.NODE_ENV === 'production' || process.env.AADHAAR_ENVIRONMENT === 'production';

    // Return cached if provider type hasn't changed
    if (this.cachedProvider && this.currentProviderType === configuredType) {
      return this.cachedProvider;
    }

    let provider: IAadhaarKycProvider;

    switch (configuredType) {
      case 'signzy':
        provider = new SignzyAadhaarProvider();
        break;
      case 'hyperverge':
        provider = new HyperVergeAadhaarProvider();
        break;
      case 'digio':
        provider = new DigiOAadhaarProvider();
        break;
      case 'sandbox':
      default:
        provider = new SandboxAadhaarProvider();
        break;
    }

    // In production, enforce that non-sandbox providers are fully configured with real credentials
    if (isProduction && configuredType !== 'sandbox' && !provider.isConfigured) {
      throw new Error('Aadhaar provider credentials/onboarding are required before production verification can be activated.');
    }

    this.cachedProvider = provider;
    this.currentProviderType = configuredType;

    console.log(`[KYC Provider] Active Aadhaar Provider: ${provider.providerName} (Configured: ${provider.isConfigured}, Sandbox: ${provider.isSandbox})`);
    return provider;
  }

  public static resetProvider(): void {
    this.cachedProvider = undefined;
    this.currentProviderType = undefined;
  }
}

export class AadhaarKycService {
  async initiateOtp(request: AadhaarOtpInitiateRequest): Promise<AadhaarOtpInitiateResponse> {
    const provider = KycProviderFactory.getProvider();
    return provider.initiateAadhaarOtp(request);
  }

  async verifyOtp(request: AadhaarOtpVerifyRequest): Promise<AadhaarOtpVerifyResponse> {
    const provider = KycProviderFactory.getProvider();
    return provider.verifyAadhaarOtp(request);
  }
}

export const aadhaarKycService = new AadhaarKycService();
