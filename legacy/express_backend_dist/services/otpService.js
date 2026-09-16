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
exports.otpService = exports.OtpService = void 0;
const sms_1 = require("./sms");
class OtpService {
    /**
     * Sanitize and normalize mobile number to standard format (+[country][number])
     * Supports standard Indian mobile numbers (10 digits -> +91XXXXXXXXXX) and international E.164
     */
    sanitizeMobile(mobileRaw) {
        if (!mobileRaw)
            return '';
        let cleaned = mobileRaw.replace(/[^\d+]/g, '').trim();
        // Strip leading 0 if 11 digits (e.g. 09876543210 -> 9876543210)
        if (cleaned.startsWith('0') && cleaned.length === 11) {
            cleaned = cleaned.substring(1);
        }
        // If starts with 91 and length is 12 digits (e.g. 919876543210), add +
        if (cleaned.length === 12 && cleaned.startsWith('91')) {
            cleaned = `+${cleaned}`;
        }
        else if (cleaned.length === 10 && /^\d{10}$/.test(cleaned)) {
            // 10-digit mobile number -> default to +91
            cleaned = `+91${cleaned}`;
        }
        else if (!cleaned.startsWith('+')) {
            cleaned = `+${cleaned}`;
        }
        return cleaned;
    }
    /**
     * Validate E.164 compliance
     */
    isValidE164(mobile) {
        return /^\+[1-9]\d{7,14}$/.test(mobile);
    }
    /**
     * Send OTP via configured SMS Gateway (2Factor / MSG91 / Sandbox)
     */
    sendOtp(mobileRaw) {
        return __awaiter(this, void 0, void 0, function* () {
            const mobile = this.sanitizeMobile(mobileRaw);
            if (!mobile || !this.isValidE164(mobile)) {
                return {
                    success: false,
                    message: 'Invalid mobile number format. Please provide a valid mobile number (e.g. +91 98765 43210).',
                    cooldownSeconds: 0,
                    expiresInSeconds: 0
                };
            }
            const provider = sms_1.SmsProviderFactory.getProvider();
            const result = yield provider.sendOtp(mobile);
            return result;
        });
    }
    /**
     * Verify entered OTP via configured SMS Gateway
     */
    verifyOtp(mobileRaw, enteredOtp, sessionId) {
        return __awaiter(this, void 0, void 0, function* () {
            const mobile = this.sanitizeMobile(mobileRaw);
            const cleanOtp = (enteredOtp || '').trim();
            if (!mobile || cleanOtp.length !== 6 || !/^\d{6}$/.test(cleanOtp)) {
                return {
                    success: false,
                    message: 'Please enter a valid 6-digit numeric verification code.'
                };
            }
            const provider = sms_1.SmsProviderFactory.getProvider();
            const result = yield provider.verifyOtp(mobile, cleanOtp, sessionId);
            return result;
        });
    }
}
exports.OtpService = OtpService;
exports.otpService = new OtpService();
