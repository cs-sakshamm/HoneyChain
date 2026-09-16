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
exports.Msg91OtpProvider = void 0;
class Msg91OtpProvider {
    constructor() {
        this.providerName = 'MSG91 (SendOTP Gateway)';
        this.baseUrl = 'https://control.msg91.com/api/v5/otp';
        this.authKey = process.env.OTP_API_KEY || process.env.MSG91_AUTH_KEY;
        this.templateId = process.env.OTP_TEMPLATE_NAME || process.env.MSG91_TEMPLATE_ID;
        this.isSandbox = process.env.OTP_ENVIRONMENT === 'sandbox' || process.env.NODE_ENV !== 'production';
    }
    get isConfigured() {
        return Boolean(this.authKey && this.authKey.length > 5);
    }
    sendOtp(mobile) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!this.isConfigured) {
                throw new Error('SMS OTP provider credentials (MSG91) and DLT onboarding are required before production OTP dispatch can be activated.');
            }
            const cleanMobile = mobile.replace(/[^\d]/g, '');
            try {
                const url = new URL(this.baseUrl);
                url.searchParams.append('authkey', this.authKey);
                url.searchParams.append('mobile', cleanMobile);
                if (this.templateId) {
                    url.searchParams.append('template_id', this.templateId);
                }
                const response = yield fetch(url.toString(), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });
                const data = yield response.json();
                if ((data === null || data === void 0 ? void 0 : data.type) !== 'success') {
                    throw new Error((data === null || data === void 0 ? void 0 : data.message) || 'MSG91 failed to dispatch OTP.');
                }
                return {
                    success: true,
                    sessionId: data.request_id || `MSG91-${Date.now()}`,
                    message: `OTP sent to ${mobile}. Valid for 5 minutes.`,
                    cooldownSeconds: 60,
                    expiresInSeconds: 300,
                    providerName: this.providerName
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to dispatch OTP via MSG91 SendOTP.');
            }
        });
    }
    verifyOtp(mobile, enteredOtp, sessionId) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!this.isConfigured) {
                throw new Error('SMS OTP provider credentials (MSG91) and DLT onboarding are required before production OTP dispatch can be activated.');
            }
            const cleanMobile = mobile.replace(/[^\d]/g, '');
            const cleanOtp = enteredOtp.trim();
            try {
                const url = new URL(`${this.baseUrl}/verify`);
                url.searchParams.append('authkey', this.authKey);
                url.searchParams.append('mobile', cleanMobile);
                url.searchParams.append('otp', cleanOtp);
                const response = yield fetch(url.toString(), { method: 'GET' });
                const data = yield response.json();
                if ((data === null || data === void 0 ? void 0 : data.type) === 'success' || (data === null || data === void 0 ? void 0 : data.message) === 'OTP verified success') {
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
                    message: (data === null || data === void 0 ? void 0 : data.message) || 'Invalid or expired verification code.',
                    providerName: this.providerName
                };
            }
            catch (err) {
                throw new Error((err === null || err === void 0 ? void 0 : err.message) || 'Failed to verify OTP with MSG91.');
            }
        });
    }
}
exports.Msg91OtpProvider = Msg91OtpProvider;
