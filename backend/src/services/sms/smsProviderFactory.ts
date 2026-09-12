import { ISmsOtpProvider, SmsOtpSendResponse, SmsOtpVerifyResponse } from './types';
import { SandboxSmsProvider } from './sandboxSmsProvider';
import { TwoFactorOtpProvider } from './twoFactorProvider';
import { Msg91OtpProvider } from './msg91Provider';

export type SmsProviderType = 'sandbox' | '2factor' | 'msg91';

export class SmsProviderFactory {
  private static cachedProvider?: ISmsOtpProvider;
  private static currentProviderType?: string;

  public static getProvider(): ISmsOtpProvider {
    const configuredType = (process.env.OTP_PROVIDER || 'sandbox').toLowerCase().trim() as SmsProviderType;
    const isProduction = process.env.NODE_ENV === 'production' || process.env.OTP_ENVIRONMENT === 'production';

    // Return cached if provider type hasn't changed
    if (this.cachedProvider && this.currentProviderType === configuredType) {
      return this.cachedProvider;
    }

    let provider: ISmsOtpProvider;

    switch (configuredType) {
      case '2factor':
        provider = new TwoFactorOtpProvider();
        break;
      case 'msg91':
        provider = new Msg91OtpProvider();
        break;
      case 'sandbox':
      default:
        provider = new SandboxSmsProvider();
        break;
    }

    // In production, enforce that external providers have API credentials configured
    if (isProduction && configuredType !== 'sandbox' && !provider.isConfigured) {
      throw new Error(`SMS OTP provider credentials (${provider.providerName}) and DLT onboarding are required before production OTP dispatch can be activated.`);
    }

    this.cachedProvider = provider;
    this.currentProviderType = configuredType;

    console.log(`[SMS OTP Provider] Active Provider: ${provider.providerName} (Configured: ${provider.isConfigured}, Sandbox: ${provider.isSandbox})`);
    return provider;
  }

  public static resetProvider(): void {
    this.cachedProvider = undefined;
    this.currentProviderType = undefined;
  }
}
