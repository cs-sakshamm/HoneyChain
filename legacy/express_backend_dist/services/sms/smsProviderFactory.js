"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SmsProviderFactory = void 0;
const sandboxSmsProvider_1 = require("./sandboxSmsProvider");
const twoFactorProvider_1 = require("./twoFactorProvider");
const msg91Provider_1 = require("./msg91Provider");
class SmsProviderFactory {
    static getProvider() {
        let configuredType = (process.env.OTP_PROVIDER || '').toLowerCase().trim();
        if (!configuredType) {
            if (process.env.MOBILE_OTP_API_KEY || process.env.OTP_API_KEY || process.env.TWOFACTOR_API_KEY) {
                configuredType = '2factor';
            }
            else {
                configuredType = 'sandbox';
            }
        }
        const isProduction = process.env.NODE_ENV === 'production' || process.env.OTP_ENVIRONMENT === 'production';
        // Return cached if provider type hasn't changed
        if (this.cachedProvider && this.currentProviderType === configuredType) {
            return this.cachedProvider;
        }
        let provider;
        switch (configuredType) {
            case '2factor':
                provider = new twoFactorProvider_1.TwoFactorOtpProvider();
                break;
            case 'msg91':
                provider = new msg91Provider_1.Msg91OtpProvider();
                break;
            case 'sandbox':
            default:
                provider = new sandboxSmsProvider_1.SandboxSmsProvider();
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
    static resetProvider() {
        this.cachedProvider = undefined;
        this.currentProviderType = undefined;
    }
}
exports.SmsProviderFactory = SmsProviderFactory;
