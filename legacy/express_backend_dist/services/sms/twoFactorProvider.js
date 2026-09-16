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
exports.TwoFactorOtpProvider = void 0;
class TwoFactorOtpProvider {
    constructor() {
        this.providerName = '2Factor (SMS OTP Gateway)';
        this.baseUrl = 'https://2factor.in/API/V1';
        this.apiKey = process.env.MOBILE_OTP_API_KEY || process.env.OTP_API_KEY || process.env.TWOFACTOR_API_KEY;
        this.senderId = process.env.MOBILE_OTP_SENDER_ID || process.env.OTP_SENDER_ID || process.env.TWOFACTOR_SENDER_ID || 'HNYCHN';
        this.templateName = process.env.MOBILE_OTP_TEMPLATE_NAME || process.env.OTP_TEMPLATE_NAME || process.env.TWOFACTOR_TEMPLATE_NAME;
        this.baseUrl = process.env.MOBILE_OTP_BASE_URL || 'https://2factor.in/API/V1';
        this.isSandbox = process.env.OTP_ENVIRONMENT === 'sandbox' || (process.env.NODE_ENV !== 'production' && !this.apiKey);
    }
    get isConfigured() {
        return Boolean(this.apiKey && this.apiKey.length > 5);
    }
    sendOtp(mobile) {
        return __awaiter(this, void 0, void 0, function* () {
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
                const response = yield fetch(endpoint);
                const data = yield response.json();
                if ((data === null || data === void 0 ? void 0 : data.Status) !== 'Success') {
                    throw new Error((data === null || data === void 0 ? void 0 : data.Details) || '2Factor failed to dispatch SMS OTP.');
                }
                return {
                    success: true,
                    sessionId: data.Details,
                    message: `OTP sent to ${mobile}. Valid for 5 minutes.`,
                    cooldownSeconds: 60,
                    expiresInSeconds: 300,
                    providerName: this.providerName
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to dispatch OTP via 2Factor SMS Gateway.');
            }
        });
    }
    verifyOtp(mobile, enteredOtp, sessionId) {
        return __awaiter(this, void 0, void 0, function* () {
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
                const response = yield fetch(endpoint);
                const data = yield response.json();
                if ((data === null || data === void 0 ? void 0 : data.Status) === 'Success' && (data === null || data === void 0 ? void 0 : data.Details) === 'OTP Matched') {
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
                    message: (data === null || data === void 0 ? void 0 : data.Details) || 'Invalid or expired verification code.',
                    providerName: this.providerName
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to verify OTP with 2Factor SMS Gateway.');
            }
        });
    }
}
exports.TwoFactorOtpProvider = TwoFactorOtpProvider;
