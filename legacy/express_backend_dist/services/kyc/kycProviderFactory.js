"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aadhaarKycService = exports.AadhaarKycService = exports.KycProviderFactory = void 0;
const sandboxProvider_1 = require("./sandboxProvider");
const signzyProvider_1 = require("./signzyProvider");
const hypervergeProvider_1 = require("./hypervergeProvider");
const digioProvider_1 = require("./digioProvider");
class KycProviderFactory {
    static getProvider() {
        const configuredType = (process.env.AADHAAR_PROVIDER || 'sandbox').toLowerCase().trim();
        const isProduction = process.env.NODE_ENV === 'production' || process.env.AADHAAR_ENVIRONMENT === 'production';
        // Return cached if provider type hasn't changed
        if (this.cachedProvider && this.currentProviderType === configuredType) {
            return this.cachedProvider;
        }
        let provider;
        switch (configuredType) {
            case 'signzy':
                provider = new signzyProvider_1.SignzyAadhaarProvider();
                break;
            case 'hyperverge':
                provider = new hypervergeProvider_1.HyperVergeAadhaarProvider();
                break;
            case 'digio':
                provider = new digioProvider_1.DigiOAadhaarProvider();
                break;
            case 'sandbox':
            default:
                provider = new sandboxProvider_1.SandboxAadhaarProvider();
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
    static resetProvider() {
        this.cachedProvider = undefined;
        this.currentProviderType = undefined;
    }
}
exports.KycProviderFactory = KycProviderFactory;
class AadhaarKycService {
    initiateOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            const provider = KycProviderFactory.getProvider();
            return provider.initiateAadhaarOtp(request);
        });
    }
    verifyOtp(request) {
        return __awaiter(this, void 0, void 0, function* () {
            const provider = KycProviderFactory.getProvider();
            return provider.verifyAadhaarOtp(request);
        });
    }
}
exports.AadhaarKycService = AadhaarKycService;
exports.aadhaarKycService = new AadhaarKycService();
